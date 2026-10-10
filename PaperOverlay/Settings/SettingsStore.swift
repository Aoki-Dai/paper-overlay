import Foundation

/// モニター 1 台ぶんの個別の質感。設定していないモニターは全体の設定に従う
struct DisplayOverride: Codable, Equatable, Sendable {
    var style: TextureStyle
    var opacity: Double
}

/// 保存する設定の値
struct OverlaySettings: Equatable, Sendable {
    /// 実際の不透明度の上限。画面では 0〜100% の「強さ」として見せ、この値を 100% にあてる
    static let maxOpacity = 0.30
    static let opacityRange: ClosedRange<Double> = 0...maxOpacity
    /// おすすめ：紙・強さ 40%（= 不透明度 12%）
    static let recommended = OverlaySettings(isEnabled: true, opacity: 0.12, style: .paper)

    var isEnabled = true
    var opacity = 0.12
    var style: TextureStyle = .paper
    /// 表示しないモニターの UUID。除外を覚える方式なので、新しく接続したモニターには自動で表示される
    var excludedDisplays: Set<String> = []
    /// モニターの UUID ごとの個別の質感
    var displayOverrides: [String: DisplayOverride] = [:]

    /// 画面に出す強さ（0〜1）。不透明度 0〜maxOpacity に比例する
    static func intensity(forOpacity opacity: Double) -> Double { opacity / maxOpacity }
    static func opacity(forIntensity intensity: Double) -> Double { min(max(intensity, 0), 1) * maxOpacity }
    static func clampedOpacity(_ opacity: Double) -> Double {
        min(max(opacity, opacityRange.lowerBound), opacityRange.upperBound)
    }
}

/// 設定の保存先。アプリでは UserDefaults、テストではメモリ上の入れ物を使う
protocol SettingsStorage: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: SettingsStorage {}

/// ディスクに書かない保存先（テストやプレビュー用）
final class InMemorySettingsStorage: SettingsStorage {
    private var values: [String: Any] = [:]

    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
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
        static let displayOverrides = "overlay.displayOverrides"
    }

    let defaults: any SettingsStorage

    init(defaults: any SettingsStorage = UserDefaults.standard) {
        self.defaults = defaults
    }

    /// 保存されていない項目・壊れた値は既定値にする
    func load() -> OverlaySettings {
        var settings = OverlaySettings()
        // bool(forKey:) や double(forKey:) は、型の違う値を false や 0 として返してしまう。
        // 0 は「見えない」になるので、数値として読めたときだけ使う
        if let isEnabled = defaults.object(forKey: Key.isEnabled) as? Bool {
            settings.isEnabled = isEnabled
        }
        if let opacity = (defaults.object(forKey: Key.opacity) as? NSNumber)?.doubleValue, opacity.isFinite {
            settings.opacity = OverlaySettings.clampedOpacity(opacity)
        }
        if let raw = defaults.object(forKey: Key.style) as? String, let style = TextureStyle(rawValue: raw) {
            settings.style = style
        }
        if let ids = defaults.object(forKey: Key.excludedDisplays) as? [String] {
            settings.excludedDisplays = Set(ids)
        }
        if let data = defaults.object(forKey: Key.displayOverrides) as? Data,
           let overrides = try? JSONDecoder().decode([String: DisplayOverride].self, from: data) {
            settings.displayOverrides = overrides.mapValues { override in
                var override = override
                override.opacity = OverlaySettings.clampedOpacity(override.opacity)
                return override
            }
        }
        return settings
    }

    /// previous と違う項目だけを書く（スライダーを動かすたびに全項目を書き直さないように）
    func save(_ settings: OverlaySettings, previous: OverlaySettings? = nil) {
        if settings.isEnabled != previous?.isEnabled {
            defaults.set(settings.isEnabled, forKey: Key.isEnabled)
        }
        if settings.opacity != previous?.opacity {
            defaults.set(settings.opacity, forKey: Key.opacity)
        }
        if settings.style != previous?.style {
            defaults.set(settings.style.rawValue, forKey: Key.style)
        }
        if settings.excludedDisplays != previous?.excludedDisplays {
            defaults.set(settings.excludedDisplays.sorted(), forKey: Key.excludedDisplays)
        }
        if settings.displayOverrides != previous?.displayOverrides,
           let data = try? JSONEncoder().encode(settings.displayOverrides) {
            defaults.set(data, forKey: Key.displayOverrides)
        }
    }
}
