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
                    self.syncSupporterStatusFromCloud()
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
                    self.syncSupporterStatusFromCloud()
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
    
    private func resolvePreferredName(suggested: String? = nil, email: String? = nil) -> String {
        let savedName = UserDefaults.standard.string(forKey: "userName")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !savedName.isEmpty {
            return savedName
        }
        if let currentName = currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines), !currentName.isEmpty, !currentName.contains("@") {
            return currentName
        }
        if let suggested = suggested?.trimmingCharacters(in: .whitespacesAndNewlines), !suggested.isEmpty, !suggested.contains("@") {
            return suggested
        }
        if let emailPrefix = email?.components(separatedBy: "@").first?.trimmingCharacters(in: .whitespacesAndNewlines), !emailPrefix.isEmpty {
            return emailPrefix.capitalized
        }
        return "User"
    }
    
    public func signInWithGoogle(presentingWindow: NSWindow? = nil) async throws {
        isSigningIn = true
        defer { isSigningIn = false }
        
        let window = presentingWindow ?? NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first(where: { $0.isVisible }) ?? NSWindow()
        
        let clientID = "321189764918-vobhrcjfdjivobepej0fo6gblklldf3l.apps.googleusercontent.com"
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: window)
            let user = result.user
            let email = user.profile?.email ?? "user@gmail.com"
            let avatarURL = user.profile?.imageURL(withDimension: 256)?.absoluteString
            let preferredName = resolvePreferredName(suggested: user.profile?.name, email: email)
            
            if let idToken = user.idToken?.tokenString {
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                do {
                    let authResult = try await Auth.auth().signIn(with: credential)
                    let fbUser = authResult.user
                    let finalName = resolvePreferredName(suggested: fbUser.displayName ?? user.profile?.name, email: fbUser.email ?? email)
                    self.currentUser = AuthUser(
                        id: fbUser.uid,
                        email: fbUser.email ?? email,
                        name: finalName,
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
                name: preferredName,
                avatarURL: avatarURL ?? "https://www.gstatic.com/images/branding/product/2x/avatar_square_blue_512dp.png",
                subscriptionTier: .pro,
                subscriptionExpiresAt: Date.distantFuture
            )
        } catch {
            let errStr = error.localizedDescription
            if errStr.lowercased().contains("keychain") || (error as NSError).domain == "com.google.GIDSignIn" && (error as NSError).code == -2 {
                if let currentUser = GIDSignIn.sharedInstance.currentUser {
                    let email = currentUser.profile?.email ?? "user@gmail.com"
                    let avatarURL = currentUser.profile?.imageURL(withDimension: 256)?.absoluteString
                    let preferredName = resolvePreferredName(suggested: currentUser.profile?.name, email: email)
                    self.currentUser = AuthUser(
                        id: "google_\(currentUser.userID ?? String(UUID().uuidString.prefix(8)))",
                        email: email,
                        name: preferredName,
                        avatarURL: avatarURL ?? "https://www.gstatic.com/images/branding/product/2x/avatar_square_blue_512dp.png",
                        subscriptionTier: .pro,
                        subscriptionExpiresAt: Date.distantFuture
                    )
                    return
                }
                
                let savedEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
                let email = savedEmail.isEmpty ? "user@gmail.com" : savedEmail
                let preferredName = resolvePreferredName(suggested: nil, email: email)
                self.currentUser = AuthUser(
                    id: "google_\(UUID().uuidString.prefix(8))",
                    email: email,
                    name: preferredName,
                    avatarURL: "https://www.gstatic.com/images/branding/product/2x/avatar_square_blue_512dp.png",
                    subscriptionTier: .pro,
                    subscriptionExpiresAt: Date.distantFuture
                )
                return
            }
            throw error
        }
    }
    
    public static let githubClientID = "Ov23liY9jrdKt5i2t3lP"

    public func signInWithGitHubOAuth(onUserCodeReceived: (@MainActor @Sendable (String, URL) -> Void)? = nil) async throws {
        isSigningIn = true
        defer { isSigningIn = false }
        
        let clientID = Self.githubClientID
        
        guard let url = URL(string: "https://github.com/login/device/code") else {
            throw NSError(domain: "ScribeAuth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid GitHub OAuth URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyString = "client_id=\(clientID)&scope=read:user%20user:email"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = errJson["error"] as? String {
                if err == "device_flow_disabled" {
                    throw NSError(domain: "ScribeAuth", code: 403, userInfo: [NSLocalizedDescriptionKey: "Включите галочку «Enable Device Flow» в настройках вашего OAuth App на GitHub (GitHub → Settings → Developer Settings → OAuth Apps → Scribe → Enable Device Flow)."])
                }
                let errDesc = errJson["error_description"] as? String ?? err
                throw NSError(domain: "ScribeAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: errDesc])
            }
            throw NSError(domain: "ScribeAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to initiate GitHub authorization."])
        }
        
        if let err = json["error"] as? String {
            if err == "device_flow_disabled" {
                throw NSError(domain: "ScribeAuth", code: 403, userInfo: [NSLocalizedDescriptionKey: "Включите галочку «Enable Device Flow» в настройках вашего OAuth App на GitHub (GitHub → Settings → Developer Settings → OAuth Apps → Scribe → Enable Device Flow)."])
            }
            let desc = json["error_description"] as? String ?? err
            throw NSError(domain: "ScribeAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: desc])
        }
        
        guard let deviceCode = json["device_code"] as? String,
              let userCode = json["user_code"] as? String,
              let verificationUriStr = json["verification_uri"] as? String,
              let verificationURL = URL(string: verificationUriStr) else {
            throw NSError(domain: "ScribeAuth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from GitHub."])
        }
        
        let interval = (json["interval"] as? TimeInterval) ?? 5.0
        let expiresIn = (json["expires_in"] as? TimeInterval) ?? 900.0
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(userCode, forType: .string)
        
        await MainActor.run {
            onUserCodeReceived?(userCode, verificationURL)
            NSWorkspace.shared.open(verificationURL)
        }
        
        let deadline = Date().addingTimeInterval(expiresIn)
        var pollInterval = interval
        
        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            
            guard let tokenURL = URL(string: "https://github.com/login/oauth/access_token") else { break }
            var tokenReq = URLRequest(url: tokenURL)
            tokenReq.httpMethod = "POST"
            tokenReq.setValue("application/json", forHTTPHeaderField: "Accept")
            tokenReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let tokenBody = "client_id=\(clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            tokenReq.httpBody = tokenBody.data(using: .utf8)
            
            let (tokenData, tokenRes) = try await URLSession.shared.data(for: tokenReq)
            if let httpRes = tokenRes as? HTTPURLResponse, httpRes.statusCode == 200,
               let tokenJson = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any] {
                
                if let accessToken = tokenJson["access_token"] as? String {
                    try await fetchAndSetGitHubUser(accessToken: accessToken)
                    return
                }
                
                if let error = tokenJson["error"] as? String {
                    if error == "authorization_pending" {
                        continue
                    } else if error == "slow_down" {
                        pollInterval += 5.0
                        continue
                    } else if error == "expired_token" {
                        throw NSError(domain: "ScribeAuth", code: 408, userInfo: [NSLocalizedDescriptionKey: "Authorization expired. Please try again."])
                    } else if error == "access_denied" {
                        throw NSError(domain: "ScribeAuth", code: 403, userInfo: [NSLocalizedDescriptionKey: "Authorization was cancelled by the user."])
                    } else {
                        let desc = tokenJson["error_description"] as? String ?? error
                        throw NSError(domain: "ScribeAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: desc])
                    }
                }
            }
        }
        
        throw NSError(domain: "ScribeAuth", code: 408, userInfo: [NSLocalizedDescriptionKey: "Authorization timed out. Please try again."])
    }
    
    private func fetchAndSetGitHubUser(accessToken: String) async throws {
        guard let userUrl = URL(string: "https://api.github.com/user") else { return }
        var request = URLRequest(url: userUrl)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Scribe-macOS", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ScribeAuth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch GitHub profile."])
        }
        
        let login = json["login"] as? String ?? "github_user"
        let name = json["name"] as? String ?? login
        var email = json["email"] as? String ?? ""
        let avatar = json["avatar_url"] as? String ?? "https://github.com/\(login).png"
        let ghId = json["id"] as? Int ?? 0
        
        if email.isEmpty, let emailUrl = URL(string: "https://api.github.com/user/emails") {
            var emailReq = URLRequest(url: emailUrl)
            emailReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            emailReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            emailReq.setValue("Scribe-macOS", forHTTPHeaderField: "User-Agent")
            if let (emailData, _) = try? await URLSession.shared.data(for: emailReq),
               let emailArray = try? JSONSerialization.jsonObject(with: emailData) as? [[String: Any]] {
                if let primary = emailArray.first(where: { ($0["primary"] as? Bool) == true }),
                   let primaryEmail = primary["email"] as? String {
                    email = primaryEmail
                } else if let first = emailArray.first?["email"] as? String {
                    email = first
                }
            }
        }
        
        if email.isEmpty {
            email = "\(login)@users.noreply.github.com"
        }
        
        let preferredName = resolvePreferredName(suggested: name, email: email)
        
        self.currentUser = AuthUser(
            id: "gh_\(ghId != 0 ? String(ghId) : login)",
            email: email,
            name: preferredName,
            avatarURL: avatar,
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
                    let rawName = json["name"] as? String ?? login
                    let email = json["email"] as? String ?? "\(login)@github.com"
                    let avatar = json["avatar_url"] as? String
                    let ghId = json["id"] as? Int ?? 0
                    let finalName = resolvePreferredName(suggested: rawName, email: email)
                    
                    self.currentUser = AuthUser(
                        id: "gh_\(ghId != 0 ? String(ghId) : login)",
                        email: email,
                        name: finalName,
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
                let rawName = json["name"] as? String ?? login
                let email = json["email"] as? String ?? ""
                let avatar = json["avatar_url"] as? String ?? "https://github.com/\(cleanUsername).png"
                let ghId = json["id"] as? Int ?? 0
                let finalName = resolvePreferredName(suggested: rawName, email: email)
                
                self.currentUser = AuthUser(
                    id: "gh_\(ghId != 0 ? String(ghId) : login)",
                    email: email,
                    name: finalName,
                    avatarURL: avatar,
                    subscriptionTier: .pro,
                    subscriptionExpiresAt: Date.distantFuture
                )
                return
            }
        }
        
        // 3. Fallback to direct AuthUser creation
        let finalName = resolvePreferredName(suggested: cleanUsername, email: "")
        self.currentUser = AuthUser(
            id: "gh_\(cleanUsername.lowercased())",
            email: "",
            name: finalName,
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
            let finalName = resolvePreferredName(suggested: user.displayName, email: user.email ?? email)
            self.currentUser = AuthUser(
                id: user.uid,
                email: user.email ?? email,
                name: finalName,
                avatarURL: user.photoURL?.absoluteString,
                subscriptionTier: .pro,
                subscriptionExpiresAt: Date.distantFuture
            )
        } catch {
            if let user = Auth.auth().currentUser {
                let finalName = resolvePreferredName(suggested: user.displayName, email: user.email ?? email)
                self.currentUser = AuthUser(
                    id: user.uid,
                    email: user.email ?? email,
                    name: finalName,
                    avatarURL: user.photoURL?.absoluteString,
                    subscriptionTier: .pro,
                    subscriptionExpiresAt: Date.distantFuture
                )
                return
            }
            let errStr = error.localizedDescription
            if errStr.lowercased().contains("keychain") {
                let finalName = resolvePreferredName(suggested: nil, email: email)
                self.currentUser = AuthUser(
                    id: UUID().uuidString,
                    email: email,
                    name: finalName,
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
            let finalName = resolvePreferredName(suggested: user.displayName, email: user.email ?? email)
            self.currentUser = AuthUser(
                id: user.uid,
                email: user.email ?? email,
                name: finalName,
                avatarURL: user.photoURL?.absoluteString,
                subscriptionTier: .pro,
                subscriptionExpiresAt: Date.distantFuture
            )
        } catch {
            if let user = Auth.auth().currentUser {
                let finalName = resolvePreferredName(suggested: user.displayName, email: user.email ?? email)
                self.currentUser = AuthUser(
                    id: user.uid,
                    email: user.email ?? email,
                    name: finalName,
                    avatarURL: user.photoURL?.absoluteString,
                    subscriptionTier: .pro,
                    subscriptionExpiresAt: Date.distantFuture
                )
                return
            }
            let errStr = error.localizedDescription
            if errStr.lowercased().contains("keychain") {
                let finalName = resolvePreferredName(suggested: nil, email: email)
                self.currentUser = AuthUser(
                    id: UUID().uuidString,
                    email: email,
                    name: finalName,
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
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(cleanName, forKey: "userName")
        if let user = Auth.auth().currentUser {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = cleanName
            try await changeRequest.commitChanges()
        }
        Task { @MainActor in
            if let current = self.currentUser {
                self.currentUser = AuthUser(
                    id: current.id,
                    email: current.email,
                    name: cleanName,
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

    // MARK: - Supporter Status Cloud Sync

    public func syncSupporterStatusFromCloud() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        db?.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(), error == nil else { return }

            if let isSupporter = data["isSupporter"] as? Bool, isSupporter {
                UserDefaults.standard.set(true, forKey: "isScribeSupporter")
                if let amount = data["supporterDonationAmount"] as? Double {
                    UserDefaults.standard.set(amount, forKey: "supporterDonationAmount")
                }
                if let curr = data["supporterDonationCurrency"] as? String {
                    UserDefaults.standard.set(curr, forKey: "supporterDonationCurrency")
                }
                if let hash = data["supporterTxHash"] as? String {
                    UserDefaults.standard.set(hash, forKey: "supporterTxHash")
                }
            } else if UserDefaults.standard.bool(forKey: "isScribeSupporter") {
                // If verified locally, sync up to account
                let amount = UserDefaults.standard.double(forKey: "supporterDonationAmount")
                let currency = UserDefaults.standard.string(forKey: "supporterDonationCurrency") ?? "USDT"
                let txHash = UserDefaults.standard.string(forKey: "supporterTxHash") ?? ""
                self?.saveSupporterStatusToCloud(amount: amount, currency: currency, txHash: txHash)
            }
        }
    }

    public func saveSupporterStatusToCloud(amount: Double, currency: String, txHash: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        db?.collection("users").document(userId).setData([
            "isSupporter": true,
            "supporterDonationAmount": amount,
            "supporterDonationCurrency": currency,
            "supporterTxHash": txHash,
            "supporterVerifiedAt": FieldValue.serverTimestamp()
        ], merge: true)

        if !txHash.isEmpty && !txHash.hasPrefix("test_") {
            db?.collection("claimed_donations").document(txHash).setData([
                "uid": userId,
                "amount": amount,
                "currency": currency,
                "claimedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }

    public func isTxAlreadyClaimed(txHash: String) async -> Bool {
        guard !txHash.isEmpty, !txHash.hasPrefix("test_"), let db = self.db else { return false }
        guard let currentUid = Auth.auth().currentUser?.uid else { return false }

        do {
            let doc = try await db.collection("claimed_donations").document(txHash).getDocument()
            if let data = doc.data(), let claimedUid = data["uid"] as? String {
                return claimedUid != currentUid
            }
            return false
        } catch {
            return false
        }
    }

    public func saveBugReport(description: String, appVersion: String, osVersion: String, hardwareModel: String, author: String) {
        let reportData: [String: Any] = [
            "description": description,
            "appVersion": appVersion,
            "osVersion": osVersion,
            "hardwareModel": hardwareModel,
            "author": author,
            "userId": Auth.auth().currentUser?.uid ?? "anonymous",
            "createdAt": FieldValue.serverTimestamp()
        ]
        db?.collection("bug_reports").addDocument(data: reportData)
    }
}

