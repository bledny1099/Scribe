import Cocoa

let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 660), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
window.makeKeyAndOrderFront(nil)

let newFrame = NSRect(x: 0, y: 0, width: 460, height: 400)
NSAnimationContext.runAnimationGroup { context in
    context.duration = 2.0
    window.animator().setFrame(newFrame, display: true)
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 3))
