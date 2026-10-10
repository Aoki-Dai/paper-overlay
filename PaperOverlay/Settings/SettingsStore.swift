import Foundation

/// 保存する設定の値
struct OverlaySettings: Equatable, Sendable {
    /// 実際の不透明度の上限。画面では 0〜100% の「強さ」として見せ、この値を 100% にあてる
    static let maxOpacity = 0.30
    static let opacityRange: ClosedRange<Double> = 0...maxOpacity
    /// おすすめ：紙・不透明度 15%（= 強さ 50%）
    static let recommended = OverlaySettings(isEnabled: true, opacity: 0.15, style: .paper)

    var isEnabled = true
    var opacity = 0.15
    var style: TextureStyle = .paper
    /// 表示しないモニターの UUID。除外を覚える方式なので、新しく接続したモニターには自動で表示される
    var excludedDisplays: Set<String> = []

    /// 画面に出す強さ（0〜1）。不透明度 0〜maxOpacity に比例する
    static func intensity(forOpacity opacity: Double) -> Double { opacity / maxOpacity }
    static func opacity(forIntensity intensity: Double) -> Double { min(max(intensity, 0), 1) * maxOpacity }
}

/// 設定を UserDefaults に読み書きする
///
/// キーを 1 つずつ分けて保存するので、`defaults read com.d4ok1.PaperOverlay` で中身を確認でき、
/// 後で App Intents など別の入口から 1 項目だけ変えるのも簡単。
struct SettingsStore {
    enum Key {
        static let isEnabled = "overlay.isEnabled"
        static let opacity = "overlay.opacity"
        static let style = "overlay.style"
        static let excludedDisplays = "overlay.excludedDisplays"
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 保存されていない項目・壊れた値は既定値にする
    func load() -> OverlaySettings {
        var settings = OverlaySettings()
        if defaults.object(forKey: Key.isEnabled) != nil {
            settings.isEnabled = defaults.bool(forKey: Key.isEnabled)
        }
        if defaults.object(forKey: Key.opacity) != nil {
            let range = OverlaySettings.opacityRange
            settings.opacity = min(max(defaults.double(forKey: Key.opacity), range.lowerBound), range.upperBound)
        }
        if let raw = defaults.string(forKey: Key.style), let style = TextureStyle(rawValue: raw) {
            settings.style = style
        }
        if let ids = defaults.stringArray(forKey: Key.excludedDisplays) {
            settings.excludedDisplays = Set(ids)
        }
        return settings
    }

    func save(_ settings: OverlaySettings) {
        defaults.set(settings.isEnabled, forKey: Key.isEnabled)
        defaults.set(settings.opacity, forKey: Key.opacity)
        defaults.set(settings.style.rawValue, forKey: Key.style)
        defaults.set(settings.excludedDisplays.sorted(), forKey: Key.excludedDisplays)
    }
}
