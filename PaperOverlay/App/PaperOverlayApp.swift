import SwiftUI

@main
struct PaperOverlayApp: App {
    var body: some Scene {
        MenuBarExtra("Paper Overlay", systemImage: "doc.plaintext") {
            Button("Quit Paper Overlay") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
