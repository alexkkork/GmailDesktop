import AppKit
import CoreGraphics
import Foundation

@inline(__always)
func isNearWhite(r: Int, g: Int, b: Int, fuzz: Int) -> Bool {
    let dr = 255 - r
    let dg = 255 - g
    let db = 255 - b
    return max(dr, max(dg, db)) <= fuzz
}

func makeTransparentBackgroundWhite(inputPath: String, outputPath: String, fuzzPercent: Float) throws {
    let url = URL(fileURLWithPath: inputPath)
    guard let nsImage = NSImage(contentsOf: url) else { throw NSError(domain: "white2alpha", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"]) }

    var rect = CGRect(origin: .zero, size: nsImage.size)
    guard let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
        throw NSError(domain: "white2alpha", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"]) }

    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var data = Data(count: height * bytesPerRow)
    let fuzz = Int(255.0 * fuzzPercent / 100.0)

    try data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
        guard let ctx = CGContext(data: ptr.baseAddress,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            throw NSError(domain: "white2alpha", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"]) }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let p = ptr.bindMemory(to: UInt8.self)
        var isBackground = Array(repeating: false, count: width * height)
        var queue = [(Int, Int)]()
        queue.reserveCapacity(width * 2 + height * 2)

        func index(_ x: Int, _ y: Int) -> Int { y * width + x }

        func enqueueIfBackground(_ x: Int, _ y: Int) {
            if x < 0 || y < 0 || x >= width || y >= height { return }
            let o = y * bytesPerRow + x * bytesPerPixel
            let r = Int(p[o + 0])
            let g = Int(p[o + 1])
            let b = Int(p[o + 2])
            let a = Int(p[o + 3])
            if a > 0 && isNearWhite(r: r, g: g, b: b, fuzz: fuzz) {
                let idx = index(x, y)
                if !isBackground[idx] { isBackground[idx] = true; queue.append((x, y)) }
            }
        }

        // Seed from image edges
        for x in 0..<width { enqueueIfBackground(x, 0); enqueueIfBackground(x, height - 1) }
        for y in 0..<height { enqueueIfBackground(0, y); enqueueIfBackground(width - 1, y) }

        // BFS flood-fill for white background connected to edges
        var head = 0
        while head < queue.count {
            let (x, y) = queue[head]; head += 1
            enqueueIfBackground(x + 1, y)
            enqueueIfBackground(x - 1, y)
            enqueueIfBackground(x, y + 1)
            enqueueIfBackground(x, y - 1)
        }

        // Clear only background-marked pixels
        for y in 0..<height {
            for x in 0..<width {
                if isBackground[index(x, y)] {
                    let o = y * bytesPerRow + x * bytesPerPixel
                    p[o + 3] = 0
                }
            }
        }

        guard let outCG = ctx.makeImage() else { throw NSError(domain: "white2alpha", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to make output image"]) }
        let rep = NSBitmapImageRep(cgImage: outCG)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "white2alpha", code: 5, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"]) }
        let outURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: outURL)
    }
}

let args = CommandLine.arguments
if args.count < 3 || args.count > 4 {
    fputs("Usage: white_to_alpha <input> <output> [fuzzPercent default 10]\n", stderr)
    exit(2)
}
let input = args[1]
let output = args[2]
let fuzz = (args.count >= 4 ? Float(args[3]) ?? 10.0 : 10.0)
try makeTransparentBackgroundWhite(inputPath: input, outputPath: output, fuzzPercent: fuzz)
