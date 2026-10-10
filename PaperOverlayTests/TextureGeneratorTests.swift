import Testing
@testable import PaperOverlay

struct TextureGeneratorTests {
    @Test func sameSeedGivesSamePixels() {
        #expect(TextureGenerator.pixels(size: 128) == TextureGenerator.pixels(size: 128))
    }

    @Test func differentSeedsGiveDifferentPixels() {
        #expect(TextureGenerator.pixels(size: 128, seed: 1) != TextureGenerator.pixels(size: 128, seed: 2))
    }

    @Test func pixelsAreOpaqueWarmPaper() {
        let pixels = TextureGenerator.pixels(size: 128)
        #expect(pixels.count == 128 * 128 * 4)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            #expect(pixels[i + 3] == 255)
            // 暖色の紙：R ≥ G ≥ B
            #expect(pixels[i] >= pixels[i + 1] && pixels[i + 1] >= pixels[i + 2])
        }
    }

    /// 白っぽくならないよう、平均の明るさを中間調に保つ
    @Test func averageIsMidToneNotWhite() {
        let pixels = TextureGenerator.pixels(size: 128)
        let reds = stride(from: 0, to: pixels.count, by: 4).map { Double(pixels[$0]) / 255 }
        let mean = reds.reduce(0, +) / Double(reds.count)
        #expect(abs(mean - TextureGenerator.baseLuminance * TextureGenerator.tint.r) < 0.03)
    }

    /// 粗さの指標：隣り合う画素の差が十分にある（細かい粒が主役になっている）
    @Test func grainIsFine() {
        let size = 128
        let pixels = TextureGenerator.pixels(size: size)
        var total = 0.0
        for y in 0..<size {
            for x in 0..<(size - 1) {
                total += abs(Double(pixels[(y * size + x) * 4]) - Double(pixels[(y * size + x + 1) * 4]))
            }
        }
        #expect(total / Double(size * (size - 1)) > 10)
    }

    @Test func tileIsRetinaResolution() {
        let tile = TextureGenerator.makeTile(pixelSize: 256, scale: 2)
        #expect(tile.size.width == 128 && tile.size.height == 128)
        #expect(tile.representations.first?.pixelsWide == 256)
    }
}
