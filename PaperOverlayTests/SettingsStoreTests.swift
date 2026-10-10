import Foundation
import Testing
@testable import PaperOverlay

struct SettingsStoreTests {
    /// テストごとに空の UserDefaults を使い、本物の設定を汚さない
    private func makeStore() -> SettingsStore {
        let name = "SettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return SettingsStore(defaults: defaults)
    }

    @Test func emptyStoreGivesDefaults() {
        #expect(makeStore().load() == OverlaySettings())
    }

    @Test func savedSettingsComeBack() {
        let store = makeStore()
        let settings = OverlaySettings(
            isEnabled: false, opacity: 0.07, style: .ePaper, excludedDisplays: ["A-UUID", "B-UUID"],
            displayOverrides: ["C-UUID": DisplayOverride(style: .paper, opacity: 0.25)])
        store.save(settings)
        #expect(store.load() == settings)
    }

    @Test func outOfRangeOpacityIsClamped() {
        let store = makeStore()
        store.defaults.set(5.0, forKey: SettingsStore.Key.opacity)
        #expect(store.load().opacity == OverlaySettings.opacityRange.upperBound)
        store.defaults.set(-1.0, forKey: SettingsStore.Key.opacity)
        #expect(store.load().opacity == OverlaySettings.opacityRange.lowerBound)
    }

    @Test func unknownStyleFallsBackToDefault() {
        let store = makeStore()
        store.defaults.set("watercolor", forKey: SettingsStore.Key.style)
        #expect(store.load().style == OverlaySettings().style)
    }

    /// お気に入りの不透明度 15% が、0〜100% の尺度でちょうど真ん中（50%）に来る
    @Test func recommendedOpacityIsHalfIntensity() {
        #expect(OverlaySettings.intensity(forOpacity: OverlaySettings.recommended.opacity) == 0.5)
        #expect(OverlaySettings.opacity(forIntensity: 1) == OverlaySettings.maxOpacity)
        #expect(OverlaySettings.opacity(forIntensity: 0) == 0)
        #expect(OverlaySettings.opacity(forIntensity: 2) == OverlaySettings.maxOpacity)
    }

    @Test func defaultsAreRecommended() {
        #expect(OverlaySettings() == OverlaySettings.recommended)
    }

    /// 除外していないモニター（新しく接続したものを含む）には表示する
    @MainActor
    @Test func excludedDisplaysAreHiddenOthersShown() {
        let overlay = OverlayController(store: makeStore())
        overlay.isEnabled = false
        let a = DisplayInfo(id: "A", name: "A", isBuiltIn: true)
        let b = DisplayInfo(id: "B", name: "B", isBuiltIn: false)
        overlay.overrideDisplaysForPreview([a, b])
        overlay.setShown(false, on: b)
        // 設定を変えると実際の画面構成で作り直されるので、一覧をもう一度差し替える
        overlay.overrideDisplaysForPreview([a, b])
        #expect(overlay.isShown(on: a))
        #expect(!overlay.isShown(on: b))
        #expect(overlay.shownDisplayCount == 1)
        overlay.setShown(true, on: b)
        #expect(overlay.excludedDisplays.isEmpty)
    }

    /// 個別に設定したモニターだけ、スタイルと強さが変わる。始めたときは全体の設定を引き継ぐ
    @MainActor
    @Test func customizedDisplayKeepsItsOwnAppearance() {
        let overlay = OverlayController(store: makeStore())
        overlay.isEnabled = false
        let a = DisplayInfo(id: "A", name: "A", isBuiltIn: true)
        let b = DisplayInfo(id: "B", name: "B", isBuiltIn: false)

        overlay.setCustomized(true, for: b)
        #expect(overlay.style(for: b) == overlay.style)
        #expect(overlay.intensity(for: b) == overlay.intensity)

        overlay.setStyle(.ePaper, for: b)
        overlay.setIntensity(1, for: b)
        overlay.style = .paper
        overlay.intensity = 0.25
        #expect(overlay.style(for: a) == .paper)
        #expect(overlay.intensity(for: a) == 0.25)
        #expect(overlay.style(for: b) == .ePaper)
        #expect(overlay.intensity(for: b) == 1)

        overlay.setCustomized(false, for: b)
        #expect(overlay.style(for: b) == .paper)
        #expect(!overlay.isCustomized(b))
    }

    @Test func overrideOpacityIsClampedOnLoad() throws {
        let store = makeStore()
        let data = try JSONEncoder().encode(["X": DisplayOverride(style: .paper, opacity: 9)])
        store.defaults.set(data, forKey: SettingsStore.Key.displayOverrides)
        #expect(store.load().displayOverrides["X"]?.opacity == OverlaySettings.maxOpacity)
    }
}
