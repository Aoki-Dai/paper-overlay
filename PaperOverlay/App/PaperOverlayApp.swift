import SwiftUI

@main
struct PaperOverlayApp: App {
    // App の初期化は起動時に 1 回。ここで作るとメニューを開く前からオーバーレイが出る
    @State private var overlay = OverlayController()

    var body: some Scene {
        MenuBarExtra("Paper Overlay", systemImage: "doc.plaintext") {
            MenuContent(overlay: overlay)
        }
    }
}

private struct MenuContent: View {
    @Bindable var overlay: OverlayController

    var body: some View {
        Toggle("Enabled", isOn: $overlay.isEnabled)

        Divider()

        Picker("Style", selection: $overlay.style) {
            ForEach(TextureStyle.allCases) { style in
                Text(style.title).tag(style)
            }
        }
        .pickerStyle(.inline)

        Divider()

        Picker("Opacity", selection: $overlay.opacity) {
            ForEach(OverlayController.opacityPresets, id: \.self) { value in
                Text(value, format: .percent.precision(.fractionLength(0))).tag(value)
            }
        }
        .pickerStyle(.inline)

        Divider()

        Button("Quit Paper Overlay") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
