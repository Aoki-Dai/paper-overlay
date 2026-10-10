import AppKit

/// 決定的な乱数。シードが同じなら毎回同じテクスチャになる
struct XorShift64 {
    var state: UInt64

    mutating func nextUnit() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state >> 11) / Double(1 << 53)
    }
}

/// 継ぎ目なく敷き詰められる紙のタイルを作る：低周波のムラ（バリューノイズ）＋画素ごとの粒子
enum TextureGenerator {
    static let defaultSeed: UInt64 = 0x2545_F491_4F6C_DD1D

    /// RGBA 8bit の画素列（size × size × 4 バイト）
    static func pixels(size: Int = 256, seed: UInt64 = defaultSeed) -> [UInt8] {
        var rng = XorShift64(state: seed)
        let cells = 8
        let cellSize = size / cells
        let grid = (0..<cells * cells).map { _ in rng.nextUnit() }

        func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
        // 端で折り返すので、タイルの右端と左端がつながる
        func at(_ cx: Int, _ cy: Int) -> Double { grid[(cy % cells) * cells + (cx % cells)] }

        func blotch(_ x: Int, _ y: Int) -> Double {
            let gx = x / cellSize, gy = y / cellSize
            let fx = smooth(Double(x % cellSize) / Double(cellSize))
            let fy = smooth(Double(y % cellSize) / Double(cellSize))
            let top = at(gx, gy) * (1 - fx) + at(gx + 1, gy) * fx
            let bottom = at(gx, gy + 1) * (1 - fx) + at(gx + 1, gy + 1) * fx
            return top * (1 - fy) + bottom * fy
        }

        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let shade = 0.88 + 0.08 * blotch(x, y) + 0.04 * rng.nextUnit()
                let i = (y * size + x) * 4
                pixels[i] = UInt8(245 * shade)
                pixels[i + 1] = UInt8(239 * shade)
                pixels[i + 2] = UInt8(226 * shade)
            }
        }
        return pixels
    }

    static func makeTile(size: Int = 256, seed: UInt64 = defaultSeed) -> NSImage {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: size * 4, bitsPerPixel: 32)!
        let source = pixels(size: size, seed: seed)
        source.withUnsafeBufferPointer { buffer in
            rep.bitmapData!.update(from: buffer.baseAddress!, count: buffer.count)
        }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(rep)
        return image
    }
}
