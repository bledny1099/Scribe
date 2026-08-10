import SwiftUI

struct TestView: View {
    var body: some View {
        ScrollView {
            VStack {
                Rectangle().fill(Color.red).frame(height: 500)
            }
            .background(GeometryReader { geo in
                Color.clear.preference(key: SizeKey.self, value: geo.size.height)
            })
        }
        .frame(height: 600)
        .onPreferenceChange(SizeKey.self) { val in
            print("Reported height changed to: \(val)")
        }
    }
}

struct SizeKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

let w = NSWindow(contentRect: NSRect(x:0, y:0, width:400, height:600), styleMask: [.titled], backing: .buffered, defer: false)
w.contentView = NSHostingView(rootView: TestView())
w.makeKeyAndOrderFront(nil)
RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))
