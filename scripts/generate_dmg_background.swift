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

// 1. Draw High-End Vertical Dark Grey to Clean White Gradient
// CoreGraphics coordinates: (0,0) is bottom-left, (0, height) is top-left
let colors = [
    NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1.0).cgColor, // Deep dark charcoal top (#1C1E24)
    NSColor(red: 0.18, green: 0.20, blue: 0.23, alpha: 1.0).cgColor, // Slate dark grey (#2E333B)
    NSColor(red: 0.38, green: 0.41, blue: 0.47, alpha: 1.0).cgColor, // Mid tone (#616978)
    NSColor(red: 0.75, green: 0.78, blue: 0.83, alpha: 1.0).cgColor, // Light platinum (#C0C7D4)
    NSColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1.0).cgColor, // Near white (#F0F2F7)
    NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0).cgColor  // Pure white bottom
] as CFArray

let locations: [CGFloat] = [0.0, 0.22, 0.48, 0.72, 0.90, 1.0]

guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
    fatalError("Could not create gradient")
}

let startPoint = CGPoint(x: width / 2, y: height) // Top (Dark Grey)
let endPoint = CGPoint(x: width / 2, y: 0)         // Bottom (White)

context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])

// 2. Subtle radial ambient glow at the top center
let ambientColors = [
    NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08).cgColor,
    NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0).cgColor
] as CFArray

if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: ambientColors, locations: [0.0, 1.0]) {
    context.drawRadialGradient(
        radialGrad,
        startCenter: CGPoint(x: width / 2, y: height),
        startRadius: 0,
        endCenter: CGPoint(x: width / 2, y: height),
        endRadius: 360,
        options: []
    )
}

// 3. Draw Connecting Directional Arrow & Pill Capsule
// Scribe icon center: (X = 175, Finder Y = 180 -> CG Y = 220)
// Applications folder center: (X = 485, Finder Y = 180 -> CG Y = 220)
let arrowY: CGFloat = 220

// Translucent glass track pill behind arrow
let pillRect = CGRect(x: 270, y: arrowY - 20, width: 120, height: 40)
let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 20, cornerHeight: 20, transform: nil)

context.saveGState()
context.setFillColor(NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.15).cgColor)
context.addPath(pillPath)
context.fillPath()

context.setStrokeColor(NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.35).cgColor)
context.setLineWidth(1.0)
context.addPath(pillPath)
context.strokePath()
context.restoreGState()

// Sleek glowing arrow inside pill
let arrowPath = CGMutablePath()
arrowPath.move(to: CGPoint(x: 290, y: arrowY))
arrowPath.addLine(to: CGPoint(x: 368, y: arrowY))

// Chevron arrowhead
arrowPath.move(to: CGPoint(x: 356, y: arrowY + 8))
arrowPath.addLine(to: CGPoint(x: 370, y: arrowY))
arrowPath.addLine(to: CGPoint(x: 356, y: arrowY - 8))

context.saveGState()
context.setStrokeColor(NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95).cgColor)
context.setLineWidth(3.0)
context.setLineCap(.round)
context.setLineJoin(.round)
context.setShadow(offset: CGSize(width: 0, height: 2), blur: 6, color: NSColor(red: 0, green: 0, blue: 0, alpha: 0.35).cgColor)
context.addPath(arrowPath)
context.strokePath()
context.restoreGState()

// 4. Apple Typography at the bottom
// Primary slogan: "One drag away from saving hours."
// Sub-caption: "Drag Scribe to Applications to install"
let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsContext

let primaryParagraph = NSMutableParagraphStyle()
primaryParagraph.alignment = .center

let primaryFont = NSFont.systemFont(ofSize: 15.0, weight: .semibold)
let primaryAttributes: [NSAttributedString.Key: Any] = [
    .font: primaryFont,
    .foregroundColor: NSColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 0.92),
    .paragraphStyle: primaryParagraph
]

let primaryString = NSAttributedString(string: "One drag away from saving hours.", attributes: primaryAttributes)
primaryString.draw(in: CGRect(x: 0, y: 44, width: width, height: 24))

let subParagraph = NSMutableParagraphStyle()
subParagraph.alignment = .center

let subFont = NSFont.systemFont(ofSize: 12.0, weight: .regular)
let subAttributes: [NSAttributedString.Key: Any] = [
    .font: subFont,
    .foregroundColor: NSColor(red: 0.45, green: 0.48, blue: 0.53, alpha: 0.85),
    .paragraphStyle: subParagraph
]

let subString = NSAttributedString(string: "Drag Scribe to Applications to install", attributes: subAttributes)
subString.draw(in: CGRect(x: 0, y: 24, width: width, height: 20))

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
