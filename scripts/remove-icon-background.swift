#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: remove-icon-background.swift input.png output.png\n", stderr)
    exit(1)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let sourceImage = NSImage(contentsOf: inputURL),
      let sourceCGImage = sourceImage.cgImage(
          forProposedRect: nil,
          context: nil,
          hints: nil
      ) else {
    fputs("Unable to read input image\n", stderr)
    exit(1)
}

let width = sourceCGImage.width
let height = sourceCGImage.height
let bytesPerPixel = 4
let bytesPerRow = width * bytesPerPixel
var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
          data: &pixels,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: bytesPerRow,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
    fputs("Unable to create image context\n", stderr)
    exit(1)
}

context.draw(
    sourceCGImage,
    in: CGRect(x: 0, y: 0, width: width, height: height)
)

func isBackgroundCandidate(_ pixelIndex: Int) -> Bool {
    let offset = pixelIndex * bytesPerPixel
    let red = Int(pixels[offset])
    let green = Int(pixels[offset + 1])
    let blue = Int(pixels[offset + 2])
    let minimum = min(red, green, blue)
    let maximum = max(red, green, blue)
    return minimum >= 190 && maximum - minimum <= 42
}

var visited = [Bool](repeating: false, count: width * height)
var queue = [Int]()
queue.reserveCapacity(width * height / 2)

func enqueue(_ index: Int) {
    guard !visited[index], isBackgroundCandidate(index) else {
        return
    }
    visited[index] = true
    queue.append(index)
}

for x in 0..<width {
    enqueue(x)
    enqueue((height - 1) * width + x)
}
for y in 0..<height {
    enqueue(y * width)
    enqueue(y * width + width - 1)
}

var cursor = 0
while cursor < queue.count {
    let index = queue[cursor]
    cursor += 1
    let x = index % width
    let y = index / width

    if x > 0 { enqueue(index - 1) }
    if x + 1 < width { enqueue(index + 1) }
    if y > 0 { enqueue(index - width) }
    if y + 1 < height { enqueue(index + width) }
}

for index in queue {
    let offset = index * bytesPerPixel
    pixels[offset] = 0
    pixels[offset + 1] = 0
    pixels[offset + 2] = 0
    pixels[offset + 3] = 0
}

guard let resultCGImage = context.makeImage() else {
    fputs("Unable to render output image\n", stderr)
    exit(1)
}

let bitmap = NSBitmapImageRep(cgImage: resultCGImage)
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode output image\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL, options: .atomic)
