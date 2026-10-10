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

/// 継ぎ目なく敷き詰められる紙のタイルを作る
///
/// SVG の feTurbulence（fractalNoise）と同じ考え方で、周期の違うバリューノイズを重ねる。
/// 細かい粒（1〜4px）を主役にし、大きなムラはごく弱くする。
enum TextureGenerator {
    static let defaultSeed: UInt64 = 0x2545_F491_4F6C_DD1D

    /// 1 オクターブ：格子の周期（px）と重み
    struct Octave {
        let period: Int
        let weight: Double
    }

    static let octaves: [Octave] = [
        Octave(period: 1, weight: 0.45),   // 画素単位の粒
        Octave(period: 2, weight: 0.30),
        Octave(period: 4, weight: 0.20),
        Octave(period: 16, weight: 0.08),
        Octave(period: 128, weight: 0.05),  // ごく弱い大きなムラ
    ]

    /// 明るさの平均。1 に近いほど画面が白っぽくなる
    static let baseLuminance = 0.62
    /// 粒の強さ（平均からの最大のずれ）
    static let grainContrast = 0.30
    /// 紙の色味（R ≥ G ≥ B の暖色）
    static let tint = (r: 1.0, g: 0.94, b: 0.84)

    /// RGBA 8bit の画素列（size × size × 4 バイト）。size は各オクターブの周期で割り切れること
    static func pixels(size: Int = 512, seed: UInt64 = defaultSeed) -> [UInt8] {
        var rng = XorShift64(state: seed)
        var field = [Double](repeating: 0, count: size * size)
        let totalWeight = octaves.reduce(0) { $0 + $1.weight }

        for octave in octaves {
            addValueNoise(into: &field, size: size, period: octave.period,
                          weight: octave.weight / totalWeight, rng: &rng)
        }

        // 重ねるほど値が 0.5 付近に集まるので、標準偏差で正規化して粒の強さをそろえる
        let mean = field.reduce(0, +) / Double(field.count)
        let variance = field.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(field.count)
        let deviation = max(variance.squareRoot(), 1e-6)

        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        for i in 0..<field.count {
            let z = max(-2.5, min(2.5, (field[i] - mean) / deviation)) / 2.5
            let luminance = baseLuminance + grainContrast * z
            pixels[i * 4] = channel(luminance * tint.r)
            pixels[i * 4 + 1] = channel(luminance * tint.g)
            pixels[i * 4 + 2] = channel(luminance * tint.b)
        }
        return pixels
    }

    /// 周期 period の格子に乱数を置き、smoothstep で補間して足し込む。格子は端で折り返す
    private static func addValueNoise(
        into field: inout [Double], size: Int, period: Int, weight: Double, rng: inout XorShift64
    ) {
        let cells = max(size / period, 1)
        let grid = (0..<cells * cells).map { _ in rng.nextUnit() }
        func at(_ cx: Int, _ cy: Int) -> Double { grid[(cy % cells) * cells + (cx % cells)] }

        if period == 1 {
            for i in 0..<field.count { field[i] += weight * grid[i] }
            return
        }

        func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
        for y in 0..<size {
            let gy = y / period
            let fy = smooth(Double(y % period) / Double(period))
            for x in 0..<size {
                let gx = x / period
                let fx = smooth(Double(x % period) / Double(period))
                let top = at(gx, gy) * (1 - fx) + at(gx + 1, gy) * fx
                let bottom = at(gx, gy + 1) * (1 - fx) + at(gx + 1, gy + 1) * fx
                field[y * size + x] += weight * (top * (1 - fy) + bottom * fy)
            }
        }
    }

    private static func channel(_ value: Double) -> UInt8 {
        UInt8(max(0, min(1, value)) * 255)
    }

    /// Retina で 1 画素 = 1 物理ピクセルになるよう、scale 倍の画素数でポイントサイズの画像を作る
    static func makeTile(pixelSize: Int = 512, scale: CGFloat = 2, seed: UInt64 = defaultSeed) -> NSImage {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: pixelSize * 4, bitsPerPixel: 32)!
        let source = pixels(size: pixelSize, seed: seed)
        source.withUnsafeBufferPointer { buffer in
            rep.bitmapData!.update(from: buffer.baseAddress!, count: buffer.count)
        }

        let points = NSSize(width: CGFloat(pixelSize) / scale, height: CGFloat(pixelSize) / scale)
        rep.size = points
        let image = NSImage(size: points)
        image.addRepresentation(rep)
        return image
    }
}
