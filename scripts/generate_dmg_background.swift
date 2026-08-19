import Cocoa
import CoreGraphics

func renderDMGBackground(scale: CGFloat) -> NSImage {
    let baseWidth: CGFloat = 660
    let baseHeight: CGFloat = 400
    
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
    
    // 1. Sleek Vertical Gradient (Dark Charcoal to Pure White)
    // CoreGraphics (0,0) is bottom-left, (0, height) is top-left
    let colors = [
        NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1.0).cgColor, // Top dark charcoal (#1C1E24)
        NSColor(red: 0.17, green: 0.19, blue: 0.22, alpha: 1.0).cgColor, // Dark slate (#2B3038)
        NSColor(red: 0.32, green: 0.35, blue: 0.40, alpha: 1.0).cgColor, // Mid tone (#525966)
        NSColor(red: 0.65, green: 0.69, blue: 0.75, alpha: 1.0).cgColor, // Platinum (#A6B0BF)
        NSColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1.0).cgColor, // Soft white (#EBF0F5)
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
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08).cgColor,
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    
    if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: ambientColors, locations: [0.0, 1.0]) {
        context.drawRadialGradient(
            radialGrad,
            startCenter: CGPoint(x: baseWidth / 2, y: baseHeight),
            startRadius: 0,
            endCenter: CGPoint(x: baseWidth / 2, y: baseHeight),
            endRadius: 360,
            options: []
        )
    }
    
    // 3. Minimalist, Ultra-Crisp Apple-Style Arrow
    // Scribe icon: X = 175, Applications: X = 485
    // Exact center between icons: X = 330, Y = 225
    let arrowY: CGFloat = 225
    let arrowCenterX: CGFloat = 330
    
    context.saveGState()
    
    // Subtle frosted glass micro-capsule
    let capsuleW: CGFloat = 88
    let capsuleH: CGFloat = 32
    let capsuleRect = CGRect(x: arrowCenterX - (capsuleW / 2), y: arrowY - (capsuleH / 2), width: capsuleW, height: capsuleH)
    let capsulePath = CGPath(roundedRect: capsuleRect, cornerWidth: capsuleH / 2, cornerHeight: capsuleH / 2, transform: nil)
    
    context.setFillColor(NSColor(white: 1.0, alpha: 0.12).cgColor)
    context.addPath(capsulePath)
    context.fillPath()
    
    context.setStrokeColor(NSColor(white: 1.0, alpha: 0.28).cgColor)
    context.setLineWidth(1.0)
    context.addPath(capsulePath)
    context.strokePath()
    
    // Crisp minimalist vector arrow
    let arrowPath = CGMutablePath()
    let shaftStart: CGFloat = arrowCenterX - 22
    let shaftEnd: CGFloat = arrowCenterX + 20
    
    // Shaft
    arrowPath.move(to: CGPoint(x: shaftStart, y: arrowY))
    arrowPath.addLine(to: CGPoint(x: shaftEnd, y: arrowY))
    
    // Head chevron
    let headSize: CGFloat = 7.0
    arrowPath.move(to: CGPoint(x: shaftEnd - headSize, y: arrowY + headSize))
    arrowPath.addLine(to: CGPoint(x: shaftEnd + 2, y: arrowY))
    arrowPath.addLine(to: CGPoint(x: shaftEnd - headSize, y: arrowY - headSize))
    
    context.setStrokeColor(NSColor(white: 1.0, alpha: 0.95).cgColor)
    context.setLineWidth(2.2)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: NSColor(white: 0.0, alpha: 0.25).cgColor)
    context.addPath(arrowPath)
    context.strokePath()
    
    context.restoreGState()
    
    // 4. Apple Typography at the bottom (elevated above Finder status bar)
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsContext
    
    let primaryParagraph = NSMutableParagraphStyle()
    primaryParagraph.alignment = .center
    
    let primaryFont = NSFont.systemFont(ofSize: 14.0, weight: .semibold)
    let primaryAttributes: [NSAttributedString.Key: Any] = [
        .font: primaryFont,
        .foregroundColor: NSColor(red: 0.12, green: 0.14, blue: 0.17, alpha: 0.95),
        .paragraphStyle: primaryParagraph
    ]
    
    let primaryString = NSAttributedString(string: "One drag away from saving hours.", attributes: primaryAttributes)
    primaryString.draw(in: CGRect(x: 0, y: 78, width: baseWidth, height: 22))
    
    let subParagraph = NSMutableParagraphStyle()
    subParagraph.alignment = .center
    
    let subFont = NSFont.systemFont(ofSize: 11.5, weight: .regular)
    let subAttributes: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(red: 0.44, green: 0.48, blue: 0.54, alpha: 0.85),
        .paragraphStyle: subParagraph
    ]
    
    let subString = NSAttributedString(string: "Drag Scribe to Applications to install", attributes: subAttributes)
    subString.draw(in: CGRect(x: 0, y: 58, width: baseWidth, height: 18))
    
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

print("Rendered 1x and 2x background images in: \(distDir)")
