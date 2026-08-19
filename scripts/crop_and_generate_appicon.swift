import AppKit
import CoreGraphics
import Foundation

let home = NSHomeDirectory()
let srcPath = "\(home)/Downloads/Scribe Logo.icon/Assets/Image.png"
guard let srcImage = NSImage(contentsOfFile: srcPath),
      let cgImage = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("❌ Failed to load source icon from \(srcPath)")
    exit(1)
}

let colorSpace = CGColorSpaceCreateDeviceRGB()

// Clean bounds of the squircle inside the mockup image
// Exactly within 180..844 in both X and Y
let cropRect = CGRect(x: 180, y: 180, width: 664, height: 664)
guard let croppedCG = cgImage.cropping(to: cropRect) else {
    print("❌ Failed to crop")
    exit(1)
}

let standardSize = 1024
// Slightly enlarged squircle icon size (880x880 inside 1024x1024 for a bold, prominent look)
let targetIconSize: CGFloat = 880.0
let targetOrigin = (CGFloat(standardSize) - targetIconSize) / 2.0
let targetRect = CGRect(x: targetOrigin, y: targetOrigin, width: targetIconSize, height: targetIconSize)
let cornerRadius: CGFloat = targetIconSize * 0.225 // Standard macOS squircle curvature (~198pt)

guard let masterCtx = CGContext(
    data: nil,
    width: standardSize,
    height: standardSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("❌ Failed to create master context")
    exit(1)
}

// Clip to Apple squircle rounded rectangle with antialiasing
let clipPath = CGPath(
    roundedRect: targetRect,
    cornerWidth: cornerRadius,
    cornerHeight: cornerRadius,
    transform: nil
)

masterCtx.addPath(clipPath)
masterCtx.clip()
masterCtx.interpolationQuality = .high
masterCtx.draw(croppedCG, in: targetRect)

guard let finalMasterCG = masterCtx.makeImage() else {
    print("❌ Failed to create final master CGImage")
    exit(1)
}

// Generate iconset
let iconsetDir = "/tmp/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in sizes {
    guard let iconCtx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }

    iconCtx.interpolationQuality = .high
    iconCtx.draw(finalMasterCG, in: CGRect(x: 0, y: 0, width: size, height: size))

    if let outImage = iconCtx.makeImage() {
        let rep = NSBitmapImageRep(cgImage: outImage)
        if let pngData = rep.representation(using: .png, properties: [:]) {
            let outURL = URL(fileURLWithPath: "\(iconsetDir)/\(filename)")
            try! pngData.write(to: outURL)
        }
    }
}

print("✅ Generated all icon sizes in \(iconsetDir)")

// Run iconutil to compile into Scribe/AppIcon.icns
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir, "-o", "Scribe/AppIcon.icns"]
try! task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("🎉 Successfully compiled enlarged Scribe/AppIcon.icns without edge artifacts!")
} else {
    print("❌ iconutil failed with exit code \(task.terminationStatus)")
}
