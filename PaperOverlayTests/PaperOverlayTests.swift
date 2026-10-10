import Foundation
import Testing
@testable import PaperOverlay

struct PaperOverlayTests {
    @Test func bundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == "com.d4ok1.PaperOverlay")
    }
}
