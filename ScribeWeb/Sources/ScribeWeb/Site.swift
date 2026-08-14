import Foundation
import Ignite

@main
struct ScribeSite {
    static func main() async {
        var site = ScribePro()
        do {
            try await site.publish()
        } catch {
            print(error)
        }
    }
}

struct ScribePro: Site {
    var name = "Scribe Pro"
    var titleSuffix = " - V4 Native Elevated"
    var url = URL(string: "http://localhost:8000")!
    
    var homePage = Home()
    var layout = ScribeLayout()
}

struct ScribeLayout: Layout {
    var body: some Document {
        PlainDocument {
            Head {
                MetaTag(name: "viewport", content: "width=device-width, initial-scale=1.0")
                MetaLink(href: "/css/custom.css?v=31", rel: .stylesheet)
                MetaLink(href: "/css/themes.css?v=8", rel: .stylesheet)
                MetaLink(href: "/css/aqua.css?v=31", rel: .stylesheet)
            }
            Body {
                content
                Script(file: "/js/app.js?v=31")
            }
        }
    }
}
