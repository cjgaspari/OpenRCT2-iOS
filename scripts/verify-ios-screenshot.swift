#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO

func fail(_ message: String) -> Never
{
    FileHandle.standardError.write(Data("iOS screenshot verification failed: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2 else
{
    fail("usage: verify-ios-screenshot.swift <screenshot.png>")
}

let screenshotPath = CommandLine.arguments[1]
let screenshotURL = URL(fileURLWithPath: screenshotPath)
guard let source = CGImageSourceCreateWithURL(screenshotURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else
{
    fail("could not decode \(screenshotPath)")
}

let width = image.width
let height = image.height
guard width > 0 && height > 0 else
{
    fail("decoded image has invalid dimensions \(width)x\(height)")
}

var pixels = [UInt8](repeating: 0, count: width * height * 4)
let bytesPerRow = width * 4
let drewImage = pixels.withUnsafeMutableBytes { storage -> Bool in
    guard let context = CGContext(
        data: storage.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else
    {
        return false
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return true
}
guard drewImage else
{
    fail("could not create an RGBA bitmap")
}

// simctl captures the iPad panel's native portrait memory order even while the
// Simulator window is landscape. Metrics are rotation-invariant, so normalize
// the logical dimensions without rewriting the source image.
let logicalWidth = max(width, height)
let logicalHeight = min(width, height)
let aspectRatio = Double(logicalWidth) / Double(logicalHeight)

let sampleStep = max(1, min(width, height) / 512)
var sampled = 0
var active = 0
var vivid = 0
var colourBuckets = Set<UInt16>()

for y in stride(from: 0, to: height, by: sampleStep)
{
    for x in stride(from: 0, to: width, by: sampleStep)
    {
        let offset = y * bytesPerRow + x * 4
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)

        sampled += 1
        if maximum > 12
        {
            active += 1
        }
        if maximum > 48 && maximum - minimum > 24
        {
            vivid += 1
        }

        let bucket = UInt16((red >> 4) << 8 | (green >> 4) << 4 | (blue >> 4))
        colourBuckets.insert(bucket)
    }
}

let activeFraction = Double(active) / Double(sampled)
let vividFraction = Double(vivid) / Double(sampled)
print(
    String(
        format: "iOS frame: raw=%dx%d logical=%dx%d aspect=%.4f active=%.3f vivid=%.3f colours=%d",
        width, height, logicalWidth, logicalHeight, aspectRatio, activeFraction, vividFraction, colourBuckets.count))

guard abs(aspectRatio - (4.0 / 3.0)) <= 0.03 else
{
    fail("expected a 4:3 landscape frame, got aspect \(aspectRatio)")
}
guard activeFraction >= 0.90 else
{
    fail(
        String(
            format: "only %.1f%% of the frame is active; rotate the Simulator to landscape and retry",
            activeFraction * 100.0))
}
guard vividFraction >= 0.40 else
{
    fail(String(format: "palette output is unexpectedly flat (vivid fraction %.3f)", vividFraction))
}
guard colourBuckets.count >= 64 else
{
    fail("palette output has only \(colourBuckets.count) sampled colour buckets")
}

print("iOS screenshot verification passed: landscape, full-frame, and palette checks are green.")
