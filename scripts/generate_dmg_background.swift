import Cocoa
import CoreGraphics

func renderDMGBackground(scale: CGFloat) -> NSImage {
    let baseWidth: CGFloat = 540
    let baseHeight: CGFloat = 360
    
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
    
    // 1. Sleek Vertical Gradient (Dark Charcoal Top to Crisp White Bottom)
    // CoreGraphics coordinates: (0,0) is bottom-left, (0, height) is top-left
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
            end: CGPoint(x: baseWidth / 2, y: 0),
            options: []
        )
    }
    
    // 2. Subtle Radial Light Accent at Top
    let ambientColors = [
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.09).cgColor,
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    
    if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: ambientColors, locations: [0.0, 1.0]) {
        context.drawRadialGradient(
            radialGrad,
            startCenter: CGPoint(x: baseWidth / 2, y: baseHeight),
            startRadius: 0,
            endCenter: CGPoint(x: baseWidth / 2, y: baseHeight),
            endRadius: 280,
            options: []
        )
    }
    
    // 3. Bold, Clean, Minimalist Apple-Style Arrow (NO OVAL / NO CAPSULE)
    // Scribe icon center: X = 140, Y = 170 in Finder -> CG Y = 360 - 170 = 190
    // Applications folder center: X = 400, Y = 170 in Finder -> CG Y = 190
    // Center between icons: X = 270, CG Y = 190
    let arrowY: CGFloat = 190
    let arrowCenterX: CGFloat = 270
    
    context.saveGState()
    
    let arrowPath = CGMutablePath()
    let shaftStart: CGFloat = arrowCenterX - 28
    let shaftEnd: CGFloat = arrowCenterX + 24
    
    // Bold Shaft
    arrowPath.move(to: CGPoint(x: shaftStart, y: arrowY))
    arrowPath.addLine(to: CGPoint(x: shaftEnd, y: arrowY))
    
    // Bold Chevron Arrowhead
    let headSpread: CGFloat = 10.0
    arrowPath.move(to: CGPoint(x: shaftEnd - headSpread, y: arrowY + headSpread))
    arrowPath.addLine(to: CGPoint(x: shaftEnd + 3, y: arrowY))
    arrowPath.addLine(to: CGPoint(x: shaftEnd - headSpread, y: arrowY - headSpread))
    
    context.setStrokeColor(NSColor(white: 1.0, alpha: 0.95).cgColor)
    context.setLineWidth(3.8)
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
        .foregroundColor: NSColor(white: 1.0, alpha: 0.95),
        .paragraphStyle: topParagraph
    ]
    
    let topString = NSAttributedString(string: "One drag away from saving hours.", attributes: topAttributes)
    topString.draw(in: CGRect(x: 0, y: baseHeight - 48, width: baseWidth, height: 26))
    
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

print("Rendered 1x and 2x background images (540x360) in: \(distDir)")
