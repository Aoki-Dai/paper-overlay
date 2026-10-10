import SwiftUI

@main
struct PaperOverlayApp: App {
    // App の初期化は起動時に 1 回。ここで作るとメニューを開く前からオーバーレイが出る
    @State private var overlay = Self.makeOverlay()

    /// 単体テストのホストとして起動されたときは、本物の設定を読まず、画面にも何も出さない
    private static func makeOverlay() -> OverlayController {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else {
            return OverlayController()
        }
        let storage = InMemorySettingsStorage()
        storage.set(false, forKey: SettingsStore.Key.isEnabled)
        return OverlayController(store: SettingsStore(defaults: storage))
    }

    var body: some Scene {
        MenuBarExtra {
            SettingsPanel(overlay: overlay)
        } label: {
            Image(systemName: overlay.isEnabled ? "doc.plaintext.fill" : "doc.plaintext")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(overlay: overlay)
        }
    }
}
