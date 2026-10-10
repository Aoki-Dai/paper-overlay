import Testing
@testable import PaperOverlay

struct TextureGeneratorTests {
    /// 隣り合う画素の差の平均（R チャンネル）。粒の細かさ・強さの指標
    private func neighborDifference(_ pixels: [UInt8], size: Int) -> Double {
        var total = 0.0
        for y in 0..<size {
            for x in 0..<(size - 1) {
                total += abs(Double(pixels[(y * size + x) * 4]) - Double(pixels[(y * size + x + 1) * 4]))
            }
        }
        return total / Double(size * (size - 1))
    }

    @Test(arguments: TextureStyle.allCases)
    func sameSeedGivesSamePixels(style: TextureStyle) {
        #expect(TextureGenerator.pixels(size: 128, style: style) == TextureGenerator.pixels(size: 128, style: style))
    }

    @Test func differentSeedsGiveDifferentPixels() {
        #expect(TextureGenerator.pixels(size: 128, seed: 1) != TextureGenerator.pixels(size: 128, seed: 2))
    }

    @Test(arguments: TextureStyle.allCases)
    func pixelsAreOpaqueAndNotBluish(style: TextureStyle) {
        let pixels = TextureGenerator.pixels(size: 128, style: style)
        #expect(pixels.count == 128 * 128 * 4)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            #expect(pixels[i + 3] == 255)
            #expect(pixels[i] >= pixels[i + 1] && pixels[i + 1] >= pixels[i + 2])
        }
    }

    /// 平均の明るさが、スタイルで決めた値から外れない（繊維を足しても白っぽく／暗くならない）
    @Test(arguments: TextureStyle.allCases)
    func averageMatchesBaseLuminance(style: TextureStyle) {
        let p = style.parameters
        let pixels = TextureGenerator.pixels(size: 256, style: style)
        let reds = stride(from: 0, to: pixels.count, by: 4).map { Double(pixels[$0]) / 255 }
        let mean = reds.reduce(0, +) / Double(reds.count)
        #expect(abs(mean - p.baseLuminance * p.tint.r) < 0.03)
    }

    @Test func paperGrainIsFine() {
        #expect(neighborDifference(TextureGenerator.pixels(size: 128, style: .paper), size: 128) > 10)
    }

    /// 電子ペーパーは紙よりずっとなめらか
    @Test func ePaperIsSmootherThanPaper() {
        let paper = neighborDifference(TextureGenerator.pixels(size: 128, style: .paper), size: 128)
        let ePaper = neighborDifference(TextureGenerator.pixels(size: 128, style: .ePaper), size: 128)
        #expect(ePaper < paper / 2)
    }

    @Test func tileIsRetinaResolution() {
        let tile = TextureGenerator.makeTile(pixelSize: 256, scale: 2)
        #expect(tile.size.width == 128 && tile.size.height == 128)
        #expect(tile.representations.first?.pixelsWide == 256)
    }
}
