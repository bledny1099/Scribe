import Cocoa
import CoreGraphics

let width: CGFloat = 660
let height: CGFloat = 400
let scale: CGFloat = 2.0

let pixelWidth = Int(width * scale)
let pixelHeight = Int(height * scale)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: pixelWidth,
    height: pixelHeight,
    bitsPerComponent: 8,
    bytesPerRow: pixelWidth * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create CGContext")
}

context.scaleBy(x: scale, y: scale)

// 1. Draw Vertical Blue to White Gradient
// Top (height): Soft sky blue (#C5E2F7 -> #DDF0FB -> #FFFFFF)
let colors = [
    NSColor(red: 0.72, green: 0.86, blue: 0.97, alpha: 1.0).cgColor, // Soft sky blue top
    NSColor(red: 0.86, green: 0.93, blue: 0.98, alpha: 1.0).cgColor, // Pale blue transition
    NSColor(red: 0.95, green: 0.98, blue: 1.00, alpha: 1.0).cgColor, // Near white
    NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0).cgColor  // Pure white bottom
] as CFArray

let locations: [CGFloat] = [0.0, 0.35, 0.70, 1.0]

guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
    fatalError("Could not create gradient")
}

// In CoreGraphics, (0,0) is bottom-left, (0, height) is top-left
let startPoint = CGPoint(x: width / 2, y: height) // Top (sky blue)
let endPoint = CGPoint(x: width / 2, y: 0)         // Bottom (white)

context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])

// 2. Draw Subtle Radial Accent in top center
let accentColors = [
    NSColor(red: 0.40, green: 0.70, blue: 0.98, alpha: 0.25).cgColor,
    NSColor(red: 0.70, green: 0.88, blue: 1.00, alpha: 0.0).cgColor
] as CFArray

if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: accentColors, locations: [0.0, 1.0]) {
    context.drawRadialGradient(
        radialGrad,
        startCenter: CGPoint(x: width / 2, y: height + 20),
        startRadius: 0,
        endCenter: CGPoint(x: width / 2, y: height + 20),
        endRadius: 320,
        options: []
    )
}

// 3. Draw connecting directional arrow between Scribe icon (175, 180) and Applications (485, 180)
// Center of arrow: X = 330, Y in Finder = 180 -> CG coords: 400 - 180 = 220
let arrowY: CGFloat = 220

let arrowPath = CGMutablePath()
// Shaft
arrowPath.move(to: CGPoint(x: 270, y: arrowY))
arrowPath.addLine(to: CGPoint(x: 385, y: arrowY))

// Head
arrowPath.move(to: CGPoint(x: 368, y: arrowY + 12))
arrowPath.addLine(to: CGPoint(x: 388, y: arrowY))
arrowPath.addLine(to: CGPoint(x: 368, y: arrowY - 12))

context.setStrokeColor(NSColor(red: 0.28, green: 0.58, blue: 0.88, alpha: 0.55).cgColor)
context.setLineWidth(3.5)
context.setLineCap(.round)
context.setLineJoin(.round)
context.addPath(arrowPath)
context.strokePath()

// 4. Draw Typography: "Drag Scribe to Applications to install"
let text = "Drag Scribe to Applications to install"
let font = NSFont.systemFont(ofSize: 13.5, weight: .semibold)
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center

let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(red: 0.20, green: 0.45, blue: 0.72, alpha: 0.85),
    .paragraphStyle: paragraphStyle
]

let attrString = NSAttributedString(string: text, attributes: attributes)
let textRect = CGRect(x: 0, y: 38, width: width, height: 26)

// Convert to NSGraphicsContext for string drawing
let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsContext
attrString.draw(in: textRect)
NSGraphicsContext.restoreGraphicsState()

// 5. Output image as PNG
guard let image = context.makeImage() else {
    fatalError("Could not create CGImage")
}

let bitmapRep = NSBitmapImageRep(cgImage: image)
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fatalError("Could not create PNG data")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_background.png"
let outputURL = URL(fileURLWithPath: outputPath)
try pngData.write(to: outputURL)

print("Generated DMG background at: \(outputPath)")
