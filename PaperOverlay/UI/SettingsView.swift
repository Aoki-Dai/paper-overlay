import SwiftUI

/// 設定ウインドウ（⌘,）
struct SettingsView: View {
    let overlay: OverlayController

    var body: some View {
        TabView {
            Tab("一般", systemImage: "gearshape") {
                GeneralSettings()
            }
            Tab("モニター", systemImage: "display.2") {
                DisplaySettings(overlay: overlay)
            }
        }
        .frame(width: 460)
    }
}

// MARK: - 一般

private struct GeneralSettings: View {
    @AppStorage(UIPreferences.showRecommendedKey) private var showRecommended = true
    @AppStorage(UIPreferences.showPresetsKey) private var showPresets = true
    @State private var loginItem = LoginItem()

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { loginItem.isEnabled || loginItem.requiresApproval },
                    set: { loginItem.setEnabled($0) }
                )) {
                    Text("ログイン時に起動")
                    Text("Mac にログインすると、自動でメニューバーに常駐します")
                }

                if loginItem.requiresApproval {
                    HStack {
                        Label("システム設定での許可が必要です", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                        Spacer()
                        Button("システム設定を開く") { loginItem.openSystemSettings() }
                    }
                }
                if let message = loginItem.errorMessage {
                    Label(message, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            } header: {
                Text("起動")
            }

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
                SectionFooter("パネルの見せ方だけが変わります。オーバーレイの強さやスタイルはそのままです。")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { loginItem.refresh() }
    }
}

// MARK: - モニター

private struct DisplaySettings: View {
    let overlay: OverlayController

    var body: some View {
        Form {
            Section {
                ForEach(overlay.displays) { display in
                    DisplayToggle(overlay: overlay, display: display)
                }
            } header: {
                Text("表示するモニター")
            } footer: {
                SectionFooter("新しく接続したモニターには、自動で表示されます。")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// モニター 1 台ぶんのオン／オフ。パネルと設定ウインドウの両方で使う
struct DisplayToggle: View {
    let overlay: OverlayController
    let display: DisplayInfo

    var body: some View {
        Toggle(isOn: Binding(
            get: { overlay.isShown(on: display) },
            set: { overlay.setShown($0, on: display) }
        )) {
            Label {
                Text(display.name)
                    .lineLimit(1)
            } icon: {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SectionFooter: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    SettingsView(overlay: OverlayController(store: SettingsStore(defaults: UserDefaults(suiteName: "preview")!)))
}
