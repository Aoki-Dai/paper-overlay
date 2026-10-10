import AppKit
import Observation

/// 画面ごとに 1 枚、枠なし・透明・クリックスルーのウインドウを重ねる
@MainActor
@Observable
final class OverlayController {
    static let opacityPresets: [Double] = [0.15, 0.20, 0.25, 0.30]

    var isEnabled = true {
        didSet { rebuild() }
    }

    var opacity = 0.20 {
        didSet { windows.forEach { $0.alphaValue = opacity } }
    }

    @ObservationIgnored private var windows: [NSWindow] = []
    @ObservationIgnored private let texture = TextureGenerator.makeTile()
    @ObservationIgnored private var screenObserver: (any NSObjectProtocol)?

    init() {
        // 画面の追加・取り外し・解像度変更に追従する（アプリと同じ寿命なので解除しない）
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
        rebuild()
    }

    func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        guard isEnabled else { return }

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame, styleMask: .borderless,
                backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = NSColor(patternImage: texture)
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [
                .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle,
            ]
            // スクリーンショットや画面共有に写さない
            window.sharingType = .none
            window.alphaValue = opacity
            window.setFrame(screen.frame, display: false)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }
}
