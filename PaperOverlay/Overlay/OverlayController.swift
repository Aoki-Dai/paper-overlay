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

    /// 全体の不透明度。個別に設定していないモニターに使う
    var opacity: Double {
        didSet {
            applyAppearance()
            persist()
        }
    }

    /// 全体のスタイル。個別に設定していないモニターに使う
    var style: TextureStyle {
        didSet {
            guard style != oldValue else { return }
            applyAppearance()
            persist()
        }
    }

    /// 表示しないモニターの UUID
    var excludedDisplays: Set<String> {
        didSet {
            guard excludedDisplays != oldValue else { return }
            rebuild()
            persist()
        }
    }

    /// モニターの UUID ごとの個別の質感
    var displayOverrides: [String: DisplayOverride] {
        didSet {
            guard displayOverrides != oldValue else { return }
            applyAppearance()
            persist()
        }
    }

    /// 接続中のモニター（画面構成が変わるたびに更新）
    private(set) var displays: [DisplayInfo] = []

    func isShown(on display: DisplayInfo) -> Bool {
        !excludedDisplays.contains(display.id)
    }

    func setShown(_ isShown: Bool, on display: DisplayInfo) {
        if isShown {
            excludedDisplays.remove(display.id)
        } else {
            excludedDisplays.insert(display.id)
        }
    }

    // MARK: モニターごとの質感

    func isCustomized(_ display: DisplayInfo) -> Bool {
        displayOverrides[display.id] != nil
    }

    /// 個別に設定を始めるときは、いまの全体の設定を引き継ぐ（見た目が急に変わらないように）
    func setCustomized(_ isCustomized: Bool, for display: DisplayInfo) {
        displayOverrides[display.id] = isCustomized
            ? DisplayOverride(style: style, opacity: opacity)
            : nil
    }

    func style(for display: DisplayInfo) -> TextureStyle {
        displayOverrides[display.id]?.style ?? style
    }

    func setStyle(_ style: TextureStyle, for display: DisplayInfo) {
        displayOverrides[display.id]?.style = style
    }

    /// 画面に出す強さ（0〜1）
    func intensity(for display: DisplayInfo) -> Double {
        OverlaySettings.intensity(forOpacity: displayOverrides[display.id]?.opacity ?? opacity)
    }

    func setIntensity(_ intensity: Double, for display: DisplayInfo) {
        displayOverrides[display.id]?.opacity = OverlaySettings.opacity(forIntensity: intensity)
    }

    #if DEBUG
    /// プレビューやテスト用に、モニターの一覧を差し替える
    func overrideDisplaysForPreview(_ displays: [DisplayInfo]) {
        self.displays = displays
    }
    #endif

    /// 表示中のモニターの台数
    var shownDisplayCount: Int {
        displays.filter { isShown(on: $0) }.count
    }

    /// 画面に出す強さ（0〜1）。opacity から計算するので、変更の通知も opacity と一緒に届く
    var intensity: Double {
        get { OverlaySettings.intensity(forOpacity: opacity) }
        set { opacity = OverlaySettings.opacity(forIntensity: newValue) }
    }

    /// 個別に設定したモニターが 1 台でもあれば、画面全体としてはおすすめの見た目ではない
    var isRecommended: Bool {
        isEnabled && displayOverrides.isEmpty && style == OverlaySettings.recommended.style
            && abs(opacity - OverlaySettings.recommended.opacity) < 0.001
    }

    /// 個別に設定しているモニターの台数
    var customizedDisplayCount: Int {
        displays.filter { isCustomized($0) }.count
    }

    /// おすすめの設定を、すべてのモニターにまとめて適用する（個別の設定は解除する）
    func applyRecommended() {
        let recommended = OverlaySettings.recommended
        displayOverrides = [:]
        style = recommended.style
        opacity = recommended.opacity
        isEnabled = recommended.isEnabled
    }

    /// 重ねているウインドウと、そのモニターの UUID
    private struct OverlayWindow {
        let displayID: String?
        let window: NSWindow
    }

    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private var windows: [OverlayWindow] = []
    /// スタイルごとのタイル。使われなくなったものは捨てる
    @ObservationIgnored private var patterns: [TextureStyle: NSColor] = [:]
    /// メインスレッドの外で生成中のスタイル
    @ObservationIgnored private var generating: Set<TextureStyle> = []
    /// 最後に保存した設定（変わった項目だけを書くため）
    @ObservationIgnored private var lastSaved: OverlaySettings
    @ObservationIgnored private var screenObserver: (any NSObjectProtocol)?

    init(store: SettingsStore = SettingsStore()) {
        // init 中の代入では didSet は呼ばれないので、読み込んだ値をそのまま入れられる
        let saved = store.load()
        self.store = store
        isEnabled = saved.isEnabled
        opacity = saved.opacity
        style = saved.style
        excludedDisplays = saved.excludedDisplays
        displayOverrides = saved.displayOverrides
        lastSaved = saved

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
        let settings = OverlaySettings(
            isEnabled: isEnabled, opacity: opacity, style: style,
            excludedDisplays: excludedDisplays, displayOverrides: displayOverrides)
        guard settings != lastSaved else { return }
        store.save(settings, previous: lastSaved)
        lastSaved = settings
    }

    /// タイルがまだなければ、メインスレッドの外で作り始めて nil を返す。
    /// できあがったら applyAppearance をやり直すので、それまでは前の見た目のまま
    private func pattern(for style: TextureStyle) -> NSColor? {
        if let pattern = patterns[style] { return pattern }
        guard !generating.contains(style) else { return nil }
        generating.insert(style)
        Task {
            let data = await Task.detached(priority: .userInitiated) {
                TextureGenerator.tileData(style: style)
            }.value
            generating.remove(style)
            patterns[style] = NSColor(patternImage: TextureGenerator.makeTile(data: data))
            applyAppearance()
        }
        return nil
    }

    /// 各ウインドウに、そのモニターのスタイルと不透明度を反映する
    private func applyAppearance() {
        var used: Set<TextureStyle> = []
        for overlay in windows {
            let override = overlay.displayID.flatMap { displayOverrides[$0] }
            let style = override?.style ?? style
            let opacity = override?.opacity ?? opacity
            used.insert(style)

            if let pattern = pattern(for: style), overlay.window.backgroundColor !== pattern {
                overlay.window.backgroundColor = pattern
            }
            if overlay.window.alphaValue != opacity {
                overlay.window.alphaValue = opacity
            }
        }
        // どの画面でも使っていないタイル（1 枚 1MB）は手放す
        patterns = patterns.filter { used.contains($0.key) || generating.contains($0.key) }
    }

    func rebuild() {
        windows.forEach { $0.window.orderOut(nil) }
        windows.removeAll()
        // オフのときもモニターの一覧は更新しておく（設定画面で選べるように）
        let screens = NSScreen.screens
        displays = screens.compactMap(\.displayInfo)
        guard isEnabled else {
            patterns.removeAll()
            return
        }

        for screen in screens {
            let displayID = screen.overlayID
            if let displayID, excludedDisplays.contains(displayID) { continue }
            let window = NSWindow(
                contentRect: screen.frame, styleMask: .borderless,
                backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            // タイルができるまでは透明にしておく（既定の背景色だと灰色が一瞬見える）
            window.backgroundColor = .clear
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
            window.setFrame(screen.frame, display: false)
            windows.append(OverlayWindow(displayID: displayID, window: window))
        }
        applyAppearance()
        windows.forEach { $0.window.orderFrontRegardless() }
    }
}
