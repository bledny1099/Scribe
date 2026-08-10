import SwiftUI

struct TestView: View {
    @State var step = 0
    @State var reportedHeight: CGFloat = 0
    
    var body: some View {
        VStack {
            Text("Reported: \(reportedHeight)")
            Button("Switch") { step = step == 0 ? 1 : 0 }
            ScrollView {
                VStack {
                    if step == 0 {
                        Rectangle().fill(Color.red).frame(height: 500)
                    } else {
                        Rectangle().fill(Color.blue).frame(height: 200)
                    }
                }
                .background(GeometryReader { geo in
                    Color.clear.preference(key: SizeKey.self, value: geo.size.height)
                })
            }
            .frame(height: 600)
        }
        .onPreferenceChange(SizeKey.self) { val in
            reportedHeight = val
            print("Reported height changed to: \(val)")
        }
    }
}

struct SizeKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

let v = NSHostingView(rootView: TestView())
v.frame = NSRect(x:0, y:0, width:400, height:800)
RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))
// Trigger button
if let testView = v.rootView as? TestView {
    print("Test ready")
}
