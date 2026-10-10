import SwiftUI

/// 設定ウインドウ（⌘,）。今後の項目が増えてもよいようにタブで分ける
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("一般", systemImage: "gearshape") {
                GeneralSettings()
            }
        }
        .frame(width: 460)
    }
}

private struct GeneralSettings: View {
    @AppStorage(UIPreferences.showRecommendedKey) private var showRecommended = true
    @AppStorage(UIPreferences.showPresetsKey) private var showPresets = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $showRecommended) {
                    Text("おすすめを表示")
                    Text("強さの★印と「おすすめ設定にする」ボタン")
                }
                Toggle(isOn: $showPresets) {
                    Text("強さのプリセットを表示")
                    Text("25・50・75・100% のボタン")
                }
            } header: {
                Text("メニューバーのパネル")
            } footer: {
                Text("パネルの見せ方だけが変わります。オーバーレイの強さやスタイルはそのままです。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    SettingsView()
}
