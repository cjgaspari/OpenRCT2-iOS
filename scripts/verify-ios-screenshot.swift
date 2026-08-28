#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO

func fail(_ message: String) -> Never
{
    FileHandle.standardError.write(Data("iOS screenshot verification failed: \(message)\n".utf8))
    exit(1)
}

enum ExpectedOrientation: String
{
    case portrait
    case landscape
}

guard CommandLine.arguments.count == 2 || CommandLine.arguments.count == 3 else
{
    fail("usage: verify-ios-screenshot.swift <screenshot.png> [portrait|landscape]")
}

let screenshotPath = CommandLine.arguments[1]
let expectedOrientation: ExpectedOrientation
if CommandLine.arguments.count == 3
{
    guard let parsed = ExpectedOrientation(rawValue: CommandLine.arguments[2]) else
    {
        fail("orientation must be portrait or landscape")
    }
    expectedOrientation = parsed
}
else
{
    expectedOrientation = .portrait
}

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

// simctl captures the device framebuffer. Do not rotate the PNG; the expected
// orientation is the physical Simulator frame.
let aspectRatio = Double(width) / Double(height)

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
        format: "iOS frame: raw=%dx%d aspect=%.4f active=%.3f vivid=%.3f colours=%d orientation=%@",
        width, height, aspectRatio, activeFraction, vividFraction, colourBuckets.count,
        expectedOrientation.rawValue))

switch expectedOrientation
{
case .portrait:
    guard height > width else
    {
        fail("expected a portrait frame, got \(width)x\(height)")
    }
    guard aspectRatio >= 0.40 && aspectRatio <= 0.82 else
    {
        fail("expected a portrait phone or iPad aspect, got \(aspectRatio)")
    }
case .landscape:
    guard width > height else
    {
        fail("expected a landscape frame, got \(width)x\(height)")
    }
    guard aspectRatio >= 1.22 && aspectRatio <= 2.50 else
    {
        fail("expected a landscape phone or iPad aspect, got \(aspectRatio)")
    }
}
guard activeFraction >= 0.55 else
{
    fail(
        String(
            format: "only %.1f%% of the frame is active; expected a full-screen game canvas",
            activeFraction * 100.0))
}
guard vividFraction >= 0.25 else
{
    fail(String(format: "palette output is unexpectedly flat (vivid fraction %.3f)", vividFraction))
}
guard colourBuckets.count >= 48 else
{
    fail("palette output has only \(colourBuckets.count) sampled colour buckets")
}

print(
    "iOS screenshot verification passed: \(expectedOrientation.rawValue), full-frame, and palette checks are green.")
