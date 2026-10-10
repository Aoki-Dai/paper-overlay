import Testing
@testable import PaperOverlay

struct TextureGeneratorTests {
    @Test func sameSeedGivesSamePixels() {
        #expect(TextureGenerator.pixels(size: 64) == TextureGenerator.pixels(size: 64))
    }

    @Test func differentSeedsGiveDifferentPixels() {
        #expect(TextureGenerator.pixels(size: 64, seed: 1) != TextureGenerator.pixels(size: 64, seed: 2))
    }

    @Test func pixelsAreOpaqueWarmPaper() {
        let pixels = TextureGenerator.pixels(size: 64)
        #expect(pixels.count == 64 * 64 * 4)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            #expect(pixels[i + 3] == 255)
            // 暖色の紙：R ≥ G ≥ B
            #expect(pixels[i] >= pixels[i + 1] && pixels[i + 1] >= pixels[i + 2])
        }
    }

    @Test func tileHasRequestedSize() {
        let tile = TextureGenerator.makeTile(size: 128)
        #expect(tile.size.width == 128 && tile.size.height == 128)
    }
}
