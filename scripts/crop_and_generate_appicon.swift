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

let width = cgImage.width
let height = cgImage.height
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bytesPerPixel = 4
let bytesPerRow = bytesPerPixel * width
let totalBytes = bytesPerRow * height

var pixels = [UInt8](repeating: 0, count: totalBytes)
guard let ctx = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("❌ Failed to create context")
    exit(1)
}
ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

// Find squircle bounding box and remove outer background
// Outer background: r > 215, g > 215, b > 215 around outer edges
// Flood-fill / corner wipe:
var isOuter = [Bool](repeating: false, count: width * height)

// BFS from 4 corners
var queue = [(Int, Int)]()
for x in 0..<width {
    queue.append((x, 0))
    queue.append((x, height - 1))
}
for y in 0..<height {
    queue.append((0, y))
    queue.append((width - 1, y))
}

var head = 0
while head < queue.count {
    let (cx, cy) = queue[head]
    head += 1

    let idx = cy * width + cx
    if isOuter[idx] { continue }

    let offset = cy * bytesPerRow + cx * bytesPerPixel
    let r = Double(pixels[offset])
    let g = Double(pixels[offset + 1])
    let b = Double(pixels[offset + 2])
    let lum = 0.299 * r + 0.587 * g + 0.114 * b

    // Background threshold (light gray/white canvas)
    if lum > 175 {
        isOuter[idx] = true

        let neighbors = [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
        for (nx, ny) in neighbors {
            if nx >= 0 && nx < width && ny >= 0 && ny < height {
                let nidx = ny * width + nx
                if !isOuter[nidx] {
                    queue.append((nx, ny))
                }
            }
        }
    }
}

// Find squircle bounds
var minX = width, maxX = 0, minY = height, maxY = 0
for y in 0..<height {
    for x in 0..<width {
        let idx = y * width + x
        if !isOuter[idx] {
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
    }
}

print("Squircle bounds: [\(minX), \(minY)] to [\(maxX), \(maxY)], size: \(maxX - minX) x \(maxY - minY)")

// Apply alpha transparency with smooth anti-aliased edge
for y in 0..<height {
    let rowStart = y * bytesPerRow
    for x in 0..<width {
        let idx = y * width + x
        let offset = rowStart + x * bytesPerPixel

        if isOuter[idx] {
            pixels[offset + 3] = 0 // 100% transparent
        } else {
            // Check distance to closest outer pixel for smooth antialiasing (1-2px)
            var hasOuterNeighbor = false
            for dy in -1...1 {
                for dx in -1...1 {
                    let nx = x + dx
                    let ny = y + dy
                    if nx >= 0 && nx < width && ny >= 0 && ny < height {
                        if isOuter[ny * width + nx] {
                            hasOuterNeighbor = true
                        }
                    }
                }
            }
            if hasOuterNeighbor {
                let r = Double(pixels[offset])
                let g = Double(pixels[offset + 1])
                let b = Double(pixels[offset + 2])
                let lum = 0.299 * r + 0.587 * g + 0.114 * b
                // If it was slightly blended with white background, reduce alpha
                if lum > 130 {
                    pixels[offset + 3] = UInt8(max(0, min(255, (175 - lum) * 5)))
                }
            }
        }
    }
}

// Save clean 1024x1024 master icon
guard let cleanCtx = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
), let cleanCG = cleanCtx.makeImage() else {
    print("❌ Failed to create clean image")
    exit(1)
}

// Crop to exact squircle and center it cleanly
let cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
guard let croppedCG = cleanCG.cropping(to: cropRect) else {
    print("❌ Failed to crop")
    exit(1)
}

// Create standard macOS 1024x1024 canvas with standard Apple icon padding (824x824 squircle centered)
let standardSize = 1024
let squircleTargetSize: CGFloat = 824
let squircleTargetOrigin = (CGFloat(standardSize) - squircleTargetSize) / 2.0
let targetRect = CGRect(x: squircleTargetOrigin, y: squircleTargetOrigin, width: squircleTargetSize, height: squircleTargetSize)

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
    print("🎉 Successfully compiled Scribe/AppIcon.icns without white borders!")
} else {
    print("❌ iconutil failed with exit code \(task.terminationStatus)")
}
