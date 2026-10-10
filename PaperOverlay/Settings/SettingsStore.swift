import Foundation

/// 保存する設定の値
struct OverlaySettings: Equatable, Sendable {
    static let opacityRange: ClosedRange<Double> = 0.03...0.40

    var isEnabled = true
    var opacity = 0.20
    var style: TextureStyle = .paper
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
        return settings
    }

    func save(_ settings: OverlaySettings) {
        defaults.set(settings.isEnabled, forKey: Key.isEnabled)
        defaults.set(settings.opacity, forKey: Key.opacity)
        defaults.set(settings.style.rawValue, forKey: Key.style)
    }
}
