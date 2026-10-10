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

    /// -1〜1 の一様乱数
    mutating func nextSigned() -> Double { nextUnit() * 2 - 1 }
}

/// 見た目の種類。生成パラメータの組み合わせで表す
enum TextureStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case paper
    case ePaper

    var id: Self { self }

    var parameters: TextureParameters {
        switch self {
        case .paper:
            TextureParameters(
                octaves: [
                    .init(period: 1, weight: 0.45),   // 画素単位の粒
                    .init(period: 2, weight: 0.30),
                    .init(period: 4, weight: 0.20),
                    .init(period: 16, weight: 0.08),
                    .init(period: 128, weight: 0.05),  // ごく弱い大きなムラ
                ],
                baseLuminance: 0.62, grainContrast: 0.30,
                tint: (r: 1.0, g: 0.94, b: 0.84),
                fibers: .init(count: 160, length: 18...70, strength: 0.40))
        case .ePaper:
            // 電子ペーパー：明るい無彩色のグレー、粒はごく弱く、ゆるやかなまだら（マイクロカプセルのムラ）
            TextureParameters(
                octaves: [
                    .init(period: 1, weight: 0.25),
                    .init(period: 2, weight: 0.20),
                    .init(period: 8, weight: 0.25),
                    .init(period: 32, weight: 0.30),
                ],
                baseLuminance: 0.80, grainContrast: 0.07,
                tint: (r: 1.0, g: 1.0, b: 0.985),
                fibers: nil)
        }
    }
}

struct TextureParameters: Sendable {
    /// 1 オクターブ：格子の周期（px）と重み
    struct Octave: Sendable {
        let period: Int
        let weight: Double
    }

    /// 繊維：512px 四方あたりの本数、長さ（px）、明るさを変える強さ
    struct Fibers: Sendable {
        let count: Int
        let length: ClosedRange<Double>
        let strength: Double
    }

    let octaves: [Octave]
    /// 明るさの平均。1 に近いほど画面が白っぽくなる
    let baseLuminance: Double
    /// 粒の強さ（平均からの最大のずれ）
    let grainContrast: Double
    /// 色味（R ≥ G ≥ B）
    let tint: (r: Double, g: Double, b: Double)
    let fibers: Fibers?
}

/// 継ぎ目なく敷き詰められるタイルを作る
///
/// SVG の feTurbulence（fractalNoise）と同じ考え方で、周期の違うバリューノイズを重ね、
/// 紙なら上から短い繊維を描き込む。
enum TextureGenerator {
    static let defaultSeed: UInt64 = 0x2545_F491_4F6C_DD1D

    /// RGBA 8bit の画素列（size × size × 4 バイト）。size は各オクターブの周期で割り切れること
    static func pixels(size: Int = 512, style: TextureStyle = .paper, seed: UInt64 = defaultSeed) -> [UInt8] {
        [UInt8](unsafeUninitializedCapacity: size * size * 4) { buffer, count in
            render(size: size, style: style, seed: seed, into: buffer)
            count = size * size * 4
        }
    }

    /// 画素を output（size × size × 4 バイト）に書き込む
    ///
    /// 途中の計算に使う数 MB の作業領域は、malloc ではなく OS から直接借りて（mmap）、終わったら返す（munmap）。
    /// malloc で確保した大きな領域は、解放してもプロセスが抱えたままになり、常駐アプリのメモリを押し上げるため。
    static func render(
        size: Int, style: TextureStyle, seed: UInt64, into output: UnsafeMutableBufferPointer<UInt8>
    ) {
        precondition(output.count >= size * size * 4)
        let p = style.parameters
        var rng = XorShift64(state: seed)
        let count = size * size

        withScratch(Double.self, count: count) { field in
            field.initialize(repeating: 0)
            let totalWeight = p.octaves.reduce(0) { $0 + $1.weight }
            for octave in p.octaves {
                addValueNoise(into: field, size: size, period: octave.period,
                              weight: octave.weight / totalWeight, rng: &rng)
            }

            // 重ねるほど値が 0.5 付近に集まるので、標準偏差で正規化して粒の強さをそろえる
            var sum = 0.0
            for value in field { sum += value }
            let mean = sum / Double(count)
            var squares = 0.0
            for value in field { squares += (value - mean) * (value - mean) }
            let deviation = max((squares / Double(count)).squareRoot(), 1e-6)

            // field をそのまま明るさに置き換える（もう 1 枚ぶんの領域を使わない）
            for i in 0..<count {
                field[i] = p.baseLuminance
                    + p.grainContrast * max(-2.5, min(2.5, (field[i] - mean) / deviation)) / 2.5
            }

            if let fibers = p.fibers {
                addFibers(into: field, size: size, fibers: fibers, rng: &rng)
            }

            for i in 0..<count {
                output[i * 4] = channel(field[i] * p.tint.r)
                output[i * 4 + 1] = channel(field[i] * p.tint.g)
                output[i * 4 + 2] = channel(field[i] * p.tint.b)
                output[i * 4 + 3] = 255
            }
        }
    }

    /// OS から直接借りた作業領域を body に渡し、終わったらすぐ返す
    private static func withScratch<T>(
        _ type: T.Type, count: Int, _ body: (UnsafeMutableBufferPointer<T>) -> Void
    ) {
        let bytes = max(count * MemoryLayout<T>.stride, 1)
        let raw = mmap(nil, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0)
        guard let raw, raw != MAP_FAILED else {
            // 借りられなければ通常の確保にフォールバックする
            let pointer = UnsafeMutablePointer<T>.allocate(capacity: count)
            defer { pointer.deallocate() }
            body(UnsafeMutableBufferPointer(start: pointer, count: count))
            return
        }
        defer { munmap(raw, bytes) }
        body(UnsafeMutableBufferPointer(start: raw.bindMemory(to: T.self, capacity: count), count: count))
    }

    /// 周期 period の格子に乱数を置き、smoothstep で補間して足し込む。格子は端で折り返す
    private static func addValueNoise(
        into field: UnsafeMutableBufferPointer<Double>, size: Int, period: Int, weight: Double,
        rng: inout XorShift64
    ) {
        let cells = max(size / period, 1)
        withScratch(Double.self, count: cells * cells) { grid in
            for i in 0..<grid.count { grid[i] = rng.nextUnit() }
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
    }

    /// ゆるく曲がる短い繊維を描く。座標を size で折り返すので、タイルの端をまたいでもつながる
    private static func addFibers(
        into luminance: UnsafeMutableBufferPointer<Double>, size: Int, fibers: TextureParameters.Fibers,
        rng: inout XorShift64
    ) {
        let s = Double(size)
        // 紙すきの流れ方向（横）にそろいやすくする
        let grainDirection = 0.0

        // 本数は 512px 四方あたりの値。小さいタイルでも密度が同じになるよう面積に比例させる
        let count = max(1, Int((Double(fibers.count) * s * s / (512 * 512)).rounded()))
        for _ in 0..<count {
            var x = rng.nextUnit() * s
            var y = rng.nextUnit() * s
            var angle = grainDirection + rng.nextSigned() * 0.9
            let bend = rng.nextSigned() * 0.008
            let length = fibers.length.lowerBound
                + rng.nextUnit() * (fibers.length.upperBound - fibers.length.lowerBound)
            // 明るい繊維と暗い繊維をまぜる（暗いほうを少し多く）
            let sign: Double = rng.nextUnit() < 0.6 ? -1 : 1
            let amount = sign * fibers.strength * (0.5 + 0.5 * rng.nextUnit())

            var travelled = 0.0
            while travelled < length {
                // 両端を細く薄くする
                let t = travelled / length
                let taper = sin(Double.pi * t)
                deposit(into: luminance, size: size, x: x, y: y, amount: amount * taper)
                x += cos(angle) * 0.5
                y += sin(angle) * 0.5
                angle += bend
                travelled += 0.5
            }
        }
    }

    /// 1 点ぶんの明るさの変化を、周囲 4 画素に重みをつけて足す（アンチエイリアス）
    private static func deposit(
        into luminance: UnsafeMutableBufferPointer<Double>, size: Int, x: Double, y: Double, amount: Double
    ) {
        let x0 = Int(x.rounded(.down)), y0 = Int(y.rounded(.down))
        let fx = x - Double(x0), fy = y - Double(y0)
        // 0.5px 刻みで同じ画素に 2 回足されるので半分にする
        let a = amount * 0.5
        // 繊維 1 本で百回以上呼ばれるので、配列を作らずに 4 画素へ直接足す
        let left = (x0 % size + size) % size, right = (left + 1) % size
        let top = (y0 % size + size) % size, bottom = (top + 1) % size
        luminance[top * size + left] += a * (1 - fx) * (1 - fy)
        luminance[top * size + right] += a * fx * (1 - fy)
        luminance[bottom * size + left] += a * (1 - fx) * fy
        luminance[bottom * size + right] += a * fx * fy
    }

    private static func channel(_ value: Double) -> UInt8 {
        UInt8(max(0, min(1, value)) * 255)
    }

    /// タイルの画素（RGBA 8bit）。重い計算なのでメインスレッドの外で呼んでよい
    static func tileData(pixelSize: Int = 512, style: TextureStyle = .paper, seed: UInt64 = defaultSeed) -> Data {
        var data = Data(count: pixelSize * pixelSize * 4)
        data.withUnsafeMutableBytes { raw in
            render(size: pixelSize, style: style, seed: seed, into: raw.bindMemory(to: UInt8.self))
        }
        return data
    }

    /// Retina で 1 画素 = 1 物理ピクセルになるよう、scale 倍の画素数でポイントサイズの画像を作る
    ///
    /// 画素は CGImage がそのまま持つ。NSBitmapImageRep を経由すると、
    /// 模様として使うときに CGImage へもう 1 枚コピーされ、タイルを 2 重に持つことになるため。
    static func makeTile(data: Data, pixelSize: Int = 512, scale: CGFloat = 2) -> NSImage {
        let image = CGImage(
            width: pixelSize, height: pixelSize, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: pixelSize * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: CGDataProvider(data: data as CFData)!, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent)!
        return NSImage(cgImage: image, size: NSSize(
            width: CGFloat(pixelSize) / scale, height: CGFloat(pixelSize) / scale))
    }

    /// 生成から画像化までを一度に行う（小さい見本やテスト用）
    static func makeTile(
        pixelSize: Int = 512, scale: CGFloat = 2, style: TextureStyle = .paper, seed: UInt64 = defaultSeed
    ) -> NSImage {
        makeTile(data: tileData(pixelSize: pixelSize, style: style, seed: seed), pixelSize: pixelSize, scale: scale)
    }
}
