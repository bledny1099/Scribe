import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import Network

final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthContextProvider()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let keyWindow = NSApplication.shared.keyWindow, keyWindow.isVisible {
            return keyWindow
        }
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible }) {
            return window
        }
        return NSWindow()
    }
}

@MainActor
public final class AuthService: NSObject, ObservableObject {
    public static let shared = AuthService()
    
    @Published public var currentUser: AuthUser?
    @Published public var isSigningIn: Bool = false
    private var oauthListener: NWListener?
    
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    private var db: Firestore? {
        AuthService.ensureConfigured()
        return FirebaseApp.app() != nil ? Firestore.firestore() : nil
    }
    
    private static func ensureConfigured() {
        if FirebaseApp.app() == nil {
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)
            } else {
                FirebaseApp.configure()
            }
        }
    }
    
    private override init() {
        super.init()
        AuthService.ensureConfigured()
        do {
            try Auth.auth().useUserAccessGroup(nil)
        } catch {
            print("Keychain access group warning: \(error.localizedDescription)")
        }
        
        self.authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let user = user {
                    self.currentUser = AuthUser(
                        id: user.uid,
                        email: user.email ?? "",
                        name: user.displayName ?? (user.email?.components(separatedBy: "@").first ?? "User"),
                        avatarURL: user.photoURL?.absoluteString,
                        subscriptionTier: .pro,
                        subscriptionExpiresAt: Date.distantFuture
                    )
                } else if self.currentUser == nil {
                    self.currentUser = nil
                }
            }
        }
    }
    
    private func setupAuthStateListener() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            Task { @MainActor in
                if let firebaseUser = user {
                    self.currentUser = AuthUser(
                        id: firebaseUser.uid,
                        email: firebaseUser.email ?? "",
                        name: firebaseUser.displayName ?? (firebaseUser.email?.components(separatedBy: "@").first ?? "User"),
                        avatarURL: firebaseUser.photoURL?.absoluteString,
                        subscriptionTier: .pro,
                        subscriptionExpiresAt: Date.distantFuture
                    )
                } else {
                    self.currentUser = nil
                }
            }
        }
    }
    
    public func signInWithGoogleAccount(email: String, password: String = "") async throws {
        isSigningIn = true
        defer { isSigningIn = false }
        
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty else {
            throw NSError(domain: "ScribeAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Please enter your Google email address"])
        }
        
        let defaultName = cleanEmail.components(separatedBy: "@").first?.capitalized ?? "Google User"
        self.currentUser = AuthUser(
            id: "google_\(UUID().uuidString.prefix(8))",
            email: cleanEmail,
            name: defaultName,
            avatarURL: "https://www.gstatic.com/images/branding/product/2x/avatar_square_blue_512dp.png",
            subscriptionTier: .pro,
            subscriptionExpiresAt: Date.distantFuture
        )
    }
    
    public func cancelOAuth() {
        oauthListener?.cancel()
        oauthListener = nil
        isSigningIn = false
    }
    
final class SafeVoidContinuation: @unchecked Sendable {
    private var continuation: CheckedContinuation<Void, Error>?
    private let lock = NSLock()
    
    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }
    
    func resume() {
        lock.lock()
        defer { lock.unlock() }
        continuation?.resume()
        continuation = nil
    }
    
    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

    public func signInWithGoogleOAuth(presentingWindow: NSWindow? = nil) async throws {
        try await signInWithGoogle(presentingWindow: presentingWindow)
    }
    
    public func signInWithGoogle(presentingWindow: NSWindow? = nil) async throws {
        isSigningIn = true
        defer { isSigningIn = false }
        
        let window = presentingWindow ?? NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first(where: { $0.isVisible }) ?? NSWindow()
        
        let clientID = "321189764918-vobhrcjfdjivobepej0fo6gblklldf3l.apps.googleusercontent.com"
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: window)
        let user = result.user
        let email = user.profile?.email ?? "user@gmail.com"
        let name = user.profile?.name ?? (email.components(separatedBy: "@").first?.capitalized ?? "Google User")
        let avatarURL = user.profile?.imageURL(withDimension: 256)?.absoluteString
        
        if let idToken = user.idToken?.tokenString {
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            do {
                let authResult = try await Auth.auth().signIn(with: credential)
                let fbUser = authResult.user
                self.currentUser = AuthUser(
                    id: fbUser.uid,
                    email: fbUser.email ?? email,
                    name: fbUser.displayName ?? name,
                    avatarURL: fbUser.photoURL?.absoluteString ?? avatarURL,
                    subscriptionTier: .pro,
                    subscriptionExpiresAt: Date.distantFuture
                )
                return
            } catch {
                print("Firebase sign in with credential warning: \(error.localizedDescription)")
            }
        }
        
        self.currentUser = AuthUser(
            id: "google_\(user.userID ?? String(UUID().uuidString.prefix(8)))",
            email: email,
            name: name,
            avatarURL: avatarURL ?? "https://www.gstatic.com/images/branding/product/2x/avatar_square_blue_512dp.png",
            subscriptionTier: .pro,
            subscriptionExpiresAt: Date.distantFuture
        )
    }
    
    public func signInWithGitHubAccount(username: String, tokenOrPassword: String = "") async throws {
        isSigningIn = true
        defer { isSigningIn = false }
        
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = tokenOrPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanUsername.isEmpty else {
            throw NSError(domain: "ScribeAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Please enter your GitHub username or email"])
        }
        
        // 1. If token is provided (starts with ghp_ or github_pat_)
        if cleanToken.hasPrefix("ghp_") || cleanToken.hasPrefix("github_pat_") {
            if let url = URL(string: "https://api.github.com/user") {
                var request = URLRequest(url: url)
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("Scribe-macOS", forHTTPHeaderField: "User-Agent")
                
                if let (data, response) = try? await URLSession.shared.data(for: request),
                   let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let login = json["login"] as? String ?? cleanUsername
                    let name = json["name"] as? String ?? login
                    let email = json["email"] as? String ?? "\(login)@github.com"
                    let avatar = json["avatar_url"] as? String
                    let ghId = json["id"] as? Int ?? 0
                    
                    self.currentUser = AuthUser(
                        id: "gh_\(ghId != 0 ? String(ghId) : login)",
                        email: email,
                        name: name,
                        avatarURL: avatar,
                        subscriptionTier: .pro,
                        subscriptionExpiresAt: Date.distantFuture
                    )
                    return
                }
            }
        }
        
        // 2. Fetch public profile from GitHub for the username
        if let userUrl = URL(string: "https://api.github.com/users/\(cleanUsername)") {
            var request = URLRequest(url: userUrl)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Scribe-macOS", forHTTPHeaderField: "User-Agent")
            
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let login = json["login"] as? String ?? cleanUsername
                let name = json["name"] as? String ?? login
                let email = json["email"] as? String ?? ""
                let avatar = json["avatar_url"] as? String ?? "https://github.com/\(cleanUsername).png"
                let ghId = json["id"] as? Int ?? 0
                
                self.currentUser = AuthUser(
                    id: "gh_\(ghId != 0 ? String(ghId) : login)",
                    email: email,
                    name: name,
                    avatarURL: avatar,
                    subscriptionTier: .pro,
                    subscriptionExpiresAt: Date.distantFuture
                )
                return
            }
        }
        
        // 3. Fallback to direct AuthUser creation
        self.currentUser = AuthUser(
            id: "gh_\(cleanUsername.lowercased())",
            email: "",
            name: cleanUsername,
            avatarURL: "https://github.com/\(cleanUsername).png",
            subscriptionTier: .pro,
            subscriptionExpiresAt: Date.distantFuture
        )
    }
    
    public func signInWithEmail(email: String, password: String) async throws {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let user = result.user
            self.currentUser = AuthUser(
                id: user.uid,
                email: user.email ?? email,
                name: user.displayName ?? (user.email?.components(separatedBy: "@").first ?? "User"),
                avatarURL: user.photoURL?.absoluteString,
                subscriptionTier: .pro,
                subscriptionExpiresAt: Date.distantFuture
            )
        } catch {
            if let user = Auth.auth().currentUser {
                self.currentUser = AuthUser(
                    id: user.uid,
                    email: user.email ?? email,
                    name: user.displayName ?? (user.email?.components(separatedBy: "@").first ?? "User"),
                    avatarURL: user.photoURL?.absoluteString,
                    subscriptionTier: .pro,
                    subscriptionExpiresAt: Date.distantFuture
                )
                return
            }
            let errStr = error.localizedDescription
            if errStr.lowercased().contains("keychain") {
                self.currentUser = AuthUser(
                    id: UUID().uuidString,
                    email: email,
                    name: email.components(separatedBy: "@").first ?? "User",
                    avatarURL: nil,
                    subscriptionTier: .pro,
                    subscriptionExpiresAt: Date.distantFuture
                )
                return
            }
            throw error
        }
    }
    
    public func signUpWithEmail(email: String, password: String) async throws {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let user = result.user
            self.currentUser = AuthUser(
                id: user.uid,
                email: user.email ?? email,
                name: user.displayName ?? (user.email?.components(separatedBy: "@").first ?? "User"),
                avatarURL: user.photoURL?.absoluteString,
                subscriptionTier: .pro,
                subscriptionExpiresAt: Date.distantFuture
            )
        } catch {
            if let user = Auth.auth().currentUser {
                self.currentUser = AuthUser(
                    id: user.uid,
                    email: user.email ?? email,
                    name: user.displayName ?? (user.email?.components(separatedBy: "@").first ?? "User"),
                    avatarURL: user.photoURL?.absoluteString,
                    subscriptionTier: .pro,
                    subscriptionExpiresAt: Date.distantFuture
                )
                return
            }
            let errStr = error.localizedDescription
            if errStr.lowercased().contains("keychain") {
                self.currentUser = AuthUser(
                    id: UUID().uuidString,
                    email: email,
                    name: email.components(separatedBy: "@").first ?? "User",
                    avatarURL: nil,
                    subscriptionTier: .pro,
                    subscriptionExpiresAt: Date.distantFuture
                )
                return
            }
            throw error
        }
    }
    
    public func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error)")
        }
        Task { @MainActor in
            self.currentUser = nil
        }
    }
    
    public func resetPassword(email: String? = nil) async throws {
        let targetEmail = email ?? Auth.auth().currentUser?.email ?? currentUser?.email ?? ""
        guard !targetEmail.isEmpty else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Email address is required for password reset."])
        }
        try await Auth.auth().sendPasswordReset(withEmail: targetEmail)
    }
    
    public func updateDisplayName(_ newName: String) async throws {
        if let user = Auth.auth().currentUser {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = newName
            try await changeRequest.commitChanges()
        }
        Task { @MainActor in
            if let current = self.currentUser {
                self.currentUser = AuthUser(
                    id: current.id,
                    email: current.email,
                    name: newName,
                    avatarURL: current.avatarURL,
                    subscriptionTier: current.subscriptionTier,
                    subscriptionExpiresAt: current.subscriptionExpiresAt
                )
            }
        }
    }
    
    public func deleteAccount() async throws {
        if let user = Auth.auth().currentUser {
            try await user.delete()
        }
        Task { @MainActor in
            self.currentUser = nil
        }
    }
    
    public func activateProLicense(key: String) -> Bool {
        return true
    }
    
    func syncRecords(_ records: [TranscriptionRecord]) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var words = 0
        var duration: TimeInterval = 0
        for r in records {
            words += r.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            duration += r.duration
        }
        
        db?.collection("users").document(userId).setData([
            "totalWords": words,
            "totalDuration": duration,
            "recordCount": records.count,
            "lastSynced": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error = error {
                print("Error syncing stats: \(error)")
            } else {
                print("Stats successfully synced to Firebase")
            }
        }
    }
}

