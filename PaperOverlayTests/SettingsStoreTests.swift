import Foundation
import Testing
@testable import PaperOverlay

struct SettingsStoreTests {
    /// テストごとにメモリ上の空の保存先を使う。本物の設定を汚さず、ファイルも残らない
    private func makeStore() -> SettingsStore {
        SettingsStore(defaults: InMemorySettingsStorage())
    }

    /// オフの状態から始めるコントローラー。本物の画面にオーバーレイを出さない
    @MainActor
    private func makeOverlay() -> OverlayController {
        let store = makeStore()
        store.defaults.set(false, forKey: SettingsStore.Key.isEnabled)
        return OverlayController(store: store)
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

    /// おすすめは強さ 40%（不透明度 12%）
    @Test func recommendedIsFortyPercentIntensity() {
        #expect(abs(OverlaySettings.intensity(forOpacity: OverlaySettings.recommended.opacity) - 0.4) < 1e-9)
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
        let overlay = makeOverlay()
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
        let overlay = makeOverlay()
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

    /// 型の違う値が保存されていても、見えなくなる（0）のではなく既定値に戻る
    @Test func wrongTypedValuesFallBackToDefaults() {
        let store = makeStore()
        store.defaults.set("abc", forKey: SettingsStore.Key.opacity)
        store.defaults.set("yes", forKey: SettingsStore.Key.isEnabled)
        #expect(store.load().opacity == OverlaySettings().opacity)
        #expect(store.load().isEnabled == OverlaySettings().isEnabled)
    }

    /// 個別に設定したモニターがあると「おすすめ」ではない。おすすめを適用すると個別の設定は解除される
    @MainActor
    @Test func recommendedClearsOverrides() {
        let overlay = makeOverlay()
        // 実際のモニターをすべて除外しておけば、オンにしても画面には何も出ない
        overlay.excludedDisplays = Set(overlay.displays.map(\.id))
        let a = DisplayInfo(id: "A", name: "A", isBuiltIn: true)

        overlay.applyRecommended()
        #expect(overlay.isRecommended)
        overlay.setCustomized(true, for: a)
        #expect(!overlay.isRecommended)
        overlay.applyRecommended()
        #expect(overlay.isRecommended)
        #expect(overlay.displayOverrides.isEmpty)
    }

    /// 変わった項目だけを書く：個別設定が同じなら JSON は書き直さない
    @Test func saveWritesOnlyChangedKeys() {
        let store = makeStore()
        var settings = OverlaySettings()
        store.save(settings)
        store.defaults.set(nil, forKey: SettingsStore.Key.displayOverrides)
        let previous = settings
        settings.opacity = 0.2
        store.save(settings, previous: previous)
        #expect(store.defaults.object(forKey: SettingsStore.Key.opacity) as? Double == 0.2)
        #expect(store.defaults.object(forKey: SettingsStore.Key.displayOverrides) == nil)
    }
}
