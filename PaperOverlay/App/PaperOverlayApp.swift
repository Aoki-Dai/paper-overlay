import SwiftUI

@main
struct PaperOverlayApp: App {
    // App の初期化は起動時に 1 回。ここで作るとメニューを開く前からオーバーレイが出る
    @State private var overlay = OverlayController()

    var body: some Scene {
        MenuBarExtra {
            SettingsPanel(overlay: overlay)
        } label: {
            Image(systemName: overlay.isEnabled ? "doc.plaintext.fill" : "doc.plaintext")
        }
        .menuBarExtraStyle(.window)
    }
}
