import AppKit
import CoreGraphics
import Foundation

let srcURL = URL(fileURLWithPath: "/Users/aleksei/.gemini/antigravity-ide/brain/203d6658-9585-4d25-8c6c-5c78ef1cdcb2/scribe_blended_app_icon_1787148172054.jpg")
guard let srcImage = NSImage(contentsOf: srcURL),
      let cgImage = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Error loading source image")
    exit(1)
}

let width = cgImage.width
let height = cgImage.height
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bytesPerPixel = 4
let bytesPerRow = bytesPerPixel * width
let totalBytes = bytesPerRow * height

// Extract source pixels
var srcPixels = [UInt8](repeating: 0, count: totalBytes)
guard let srcContext = CGContext(
    data: &srcPixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Error creating source context")
    exit(1)
}
srcContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

// Prepare output buffers
var bgPixels = [UInt8](repeating: 0, count: totalBytes)
var micPixels = [UInt8](repeating: 0, count: totalBytes)
var wavePixels = [UInt8](repeating: 0, count: totalBytes)
var fgPixels = [UInt8](repeating: 0, count: totalBytes)

for y in 0..<height {
    let rowStart = y * bytesPerRow
    let progressY = CGFloat(y) / CGFloat(height)
    let estimatedBgLum = UInt8(min(255, max(0, Int(255.0 * (0.24 + progressY * 0.08)))))

    for x in 0..<width {
        let offset = rowStart + x * bytesPerPixel
        let r = srcPixels[offset]
        let g = srcPixels[offset + 1]
        let b = srcPixels[offset + 2]
        let a = srcPixels[offset + 3]

        let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)

        // Outer white canvas around rounded squircle
        let isOuterBg = r > 225 && g > 225 && b > 225 && (x < 150 || x > 874 || y < 150 || y > 874)

        // Mic vs Waveform bounding regions
        let isWaveformRegion = ((x >= 180 && x <= 400) || (x >= 625 && x <= 845)) && (y >= 280 && y <= 740)
        let isMicRegion = (x >= 390 && x <= 635) && (y >= 260 && y <= 760)

        // 1. Background Layer
        if !isOuterBg {
            if (isMicRegion || isWaveformRegion) && luminance > 105 {
                // Inpaint clean dark background
                bgPixels[offset] = estimatedBgLum
                bgPixels[offset + 1] = estimatedBgLum
                bgPixels[offset + 2] = UInt8(min(255, Int(Double(estimatedBgLum) * 1.08)))
                bgPixels[offset + 3] = 255
            } else {
                bgPixels[offset] = r
                bgPixels[offset + 1] = g
                bgPixels[offset + 2] = b
                bgPixels[offset + 3] = a
            }
        }

        // 2. Foreground Elements Layer
        if !isOuterBg {
            let bgThreshold: Double = 80.0
            if luminance > bgThreshold {
                let alphaFactor = min(1.0, max(0.0, (luminance - bgThreshold) / 50.0))
                let alpha = UInt8(Double(a) * alphaFactor)

                if alpha > 10 {
                    // Combined foreground
                    fgPixels[offset] = r
                    fgPixels[offset + 1] = g
                    fgPixels[offset + 2] = b
                    fgPixels[offset + 3] = alpha

                    // Mic only
                    if isMicRegion {
                        micPixels[offset] = r
                        micPixels[offset + 1] = g
                        micPixels[offset + 2] = b
                        micPixels[offset + 3] = alpha
                    }

                    // Waveform only
                    if isWaveformRegion {
                        wavePixels[offset] = r
                        wavePixels[offset + 1] = g
                        wavePixels[offset + 2] = b
                        wavePixels[offset + 3] = alpha
                    }
                }
            }
        }
    }
}

// Function to save buffer to PNG
func saveBuffer(_ buffer: inout [UInt8], to path: String) {
    guard let ctx = CGContext(
        data: &buffer,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let outCG = ctx.makeImage() else {
        print("Failed to create image for \(path)")
        return
    }

    let rep = NSBitmapImageRep(cgImage: outCG)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try! data.write(to: URL(fileURLWithPath: path))
    print("✅ Exported: \(path)")
}

let outDir = "assets/icon_composer_layers"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

saveBuffer(&bgPixels, to: "\(outDir)/Layer_1_Background.png")
saveBuffer(&micPixels, to: "\(outDir)/Layer_2_Microphone.png")
saveBuffer(&wavePixels, to: "\(outDir)/Layer_3_Soundwave.png")
saveBuffer(&fgPixels, to: "\(outDir)/Layer_Combined_Foreground.png")

// Copy original master image as well
let origData = try! Data(contentsOf: srcURL)
try! origData.write(to: URL(fileURLWithPath: "\(outDir)/Master_Icon_Original.png"))
print("✅ Copied original to: \(outDir)/Master_Icon_Original.png")
