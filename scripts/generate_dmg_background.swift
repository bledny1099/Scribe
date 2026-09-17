import Cocoa
import CoreGraphics

func renderDMGBackground(scale: CGFloat) -> NSImage {
    // Ultra-wide high resolution canvas so Finder background seamlessly covers any window width or resizing
    let baseWidth: CGFloat = 2560
    let baseHeight: CGFloat = 1200
    
    // Layout anchor coordinates (matches compact window 540x420)
    let contentWidth: CGFloat = 540
    let contentHeight: CGFloat = 420
    let contentCenterX: CGFloat = contentWidth / 2 // 270
    
    let pixelWidth = Int(baseWidth * scale)
    let pixelHeight = Int(baseHeight * scale)
    
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
    
    // 1. Sleek Vertical Gradient (Dark Charcoal Top to Soft White Bottom)
    // Extends across full 2560 width so no matter how wide the window is, the gradient never disappears
    let colors = [
        NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1.0).cgColor, // Top dark charcoal (#1C1E24)
        NSColor(red: 0.16, green: 0.18, blue: 0.21, alpha: 1.0).cgColor, // Slate dark (#292E36)
        NSColor(red: 0.30, green: 0.33, blue: 0.38, alpha: 1.0).cgColor, // Mid tone (#4D5461)
        NSColor(red: 0.65, green: 0.69, blue: 0.75, alpha: 1.0).cgColor, // Platinum (#A6B0BF)
        NSColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 1.0).cgColor, // Near white (#EDF2F7)
        NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0).cgColor  // Pure white (#FFFFFF)
    ] as CFArray
    
    let locations: [CGFloat] = [0.0, 0.20, 0.44, 0.68, 0.88, 1.0]
    
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: baseWidth / 2, y: baseHeight),
            end: CGPoint(x: baseWidth / 2, y: baseHeight - contentHeight),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
    
    // 2. Subtle Radial Light Accent at Top centered above content
    let ambientColors = [
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.09).cgColor,
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    
    if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: ambientColors, locations: [0.0, 1.0]) {
        context.drawRadialGradient(
            radialGrad,
            startCenter: CGPoint(x: contentCenterX, y: baseHeight),
            startRadius: 0,
            endCenter: CGPoint(x: contentCenterX, y: baseHeight),
            endRadius: 340,
            options: []
        )
    }
    
    // 3. Bold, Clean, Minimalist Apple-Style Arrow
    // Scribe icon center: X = 135, Y = 135 in Finder -> CG Y = baseHeight - 135
    // Applications folder center: X = 405, Y = 135 in Finder -> CG Y = baseHeight - 135
    // Center between icons: X = 270
    let arrowY: CGFloat = baseHeight - 135
    let arrowCenterX: CGFloat = contentCenterX
    
    context.saveGState()
    
    let arrowPath = CGMutablePath()
    let shaftStart: CGFloat = arrowCenterX - 26
    let shaftEnd: CGFloat = arrowCenterX + 22
    
    // Bold Shaft
    arrowPath.move(to: CGPoint(x: shaftStart, y: arrowY))
    arrowPath.addLine(to: CGPoint(x: shaftEnd, y: arrowY))
    
    // Bold Chevron Arrowhead
    let headSpread: CGFloat = 9.5
    arrowPath.move(to: CGPoint(x: shaftEnd - headSpread, y: arrowY + headSpread))
    arrowPath.addLine(to: CGPoint(x: shaftEnd + 3, y: arrowY))
    arrowPath.addLine(to: CGPoint(x: shaftEnd - headSpread, y: arrowY - headSpread))
    
    context.setStrokeColor(NSColor(white: 1.0, alpha: 0.95).cgColor)
    context.setLineWidth(3.6)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 5, color: NSColor(white: 0.0, alpha: 0.35).cgColor)
    context.addPath(arrowPath)
    context.strokePath()
    
    context.restoreGState()
    
    // 4. Typography
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsContext
    
    // Top Slogan (Large, prominent, clean white on dark charcoal)
    let topParagraph = NSMutableParagraphStyle()
    topParagraph.alignment = .center
    
    let topFont = NSFont.systemFont(ofSize: 17.5, weight: .bold)
    let topAttributes: [NSAttributedString.Key: Any] = [
        .font: topFont,
        .foregroundColor: NSColor(white: 1.0, alpha: 0.96),
        .paragraphStyle: topParagraph
    ]
    
    let topString = NSAttributedString(string: "One drag away from saving hours.", attributes: topAttributes)
    topString.draw(in: CGRect(x: 0, y: baseHeight - 38, width: contentWidth, height: 24))
    
    // Subtitle helper
    let subParagraph = NSMutableParagraphStyle()
    subParagraph.alignment = .center
    let subFont = NSFont.systemFont(ofSize: 11.5, weight: .medium)
    let subAttributes: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(white: 1.0, alpha: 0.70),
        .paragraphStyle: subParagraph
    ]
    let subString = NSAttributedString(string: "Drag to Applications • If blocked by Gatekeeper, see README below", attributes: subAttributes)
    subString.draw(in: CGRect(x: 0, y: baseHeight - 56, width: contentWidth, height: 16))
    
    NSGraphicsContext.restoreGraphicsState()
    
    guard let cgImage = context.makeImage() else {
        fatalError("Could not create CGImage")
    }
    
    return NSImage(cgImage: cgImage, size: NSSize(width: baseWidth, height: baseHeight))
}

// Generate 1x and 2x versions
let img1x = renderDMGBackground(scale: 1.0)
let img2x = renderDMGBackground(scale: 2.0)

let distDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist"
let url1x = URL(fileURLWithPath: "\(distDir)/dmg_bg.png")
let url2x = URL(fileURLWithPath: "\(distDir)/dmg_bg@2x.png")

if let tiff1x = img1x.tiffRepresentation, let rep1x = NSBitmapImageRep(data: tiff1x), let png1x = rep1x.representation(using: .png, properties: [:]) {
    try png1x.write(to: url1x)
}

if let tiff2x = img2x.tiffRepresentation, let rep2x = NSBitmapImageRep(data: tiff2x), let png2x = rep2x.representation(using: .png, properties: [:]) {
    try png2x.write(to: url2x)
}

print("Rendered 1x and 2x background images (2560x1200) in: \(distDir)")
