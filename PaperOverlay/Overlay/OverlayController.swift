import AppKit
import Observation

/// 画面ごとに 1 枚、枠なし・透明・クリックスルーのウインドウを重ねる
@MainActor
@Observable
final class OverlayController {
    var isEnabled: Bool {
        didSet {
            rebuild()
            persist()
        }
    }

    var opacity: Double {
        didSet {
            windows.forEach { $0.alphaValue = opacity }
            persist()
        }
    }

    var style: TextureStyle {
        didSet {
            guard style != oldValue else { return }
            texture = TextureGenerator.makeTile(style: style)
            windows.forEach { $0.backgroundColor = NSColor(patternImage: texture) }
            persist()
        }
    }

    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private var windows: [NSWindow] = []
    @ObservationIgnored private var texture: NSImage
    @ObservationIgnored private var screenObserver: (any NSObjectProtocol)?

    init(store: SettingsStore = SettingsStore()) {
        // init 中の代入では didSet は呼ばれないので、読み込んだ値をそのまま入れられる
        let saved = store.load()
        self.store = store
        isEnabled = saved.isEnabled
        opacity = saved.opacity
        style = saved.style
        texture = TextureGenerator.makeTile(style: saved.style)

        // 画面の追加・取り外し・解像度変更に追従する（アプリと同じ寿命なので解除しない）
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
        rebuild()
    }

    private func persist() {
        store.save(OverlaySettings(isEnabled: isEnabled, opacity: opacity, style: style))
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
            #if DEBUG
            // 見た目を screencapture で確認できるよう、デバッグビルドでは写す
            window.sharingType = .readOnly
            #else
            // スクリーンショットや画面共有に写さない
            window.sharingType = .none
            #endif
            window.alphaValue = opacity
            window.setFrame(screen.frame, display: false)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }
}
