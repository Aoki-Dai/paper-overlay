/// パネルの見せ方の設定（@AppStorage のキー）。オーバーレイ自体の動作には影響しない
enum UIPreferences {
    /// 強さの★印と「おすすめ設定にする」ボタンを表示する
    static let showRecommendedKey = "ui.showRecommended"
    /// 強さのプリセットボタン（25・50・75・100%）を表示する
    static let showPresetsKey = "ui.showPresets"
}
