import AppKit

// MARK: - Texture

/// Tiny deterministic PRNG so both implementations produce the same texture.
struct XorShift64 {
    var state: UInt64
    mutating func nextUnit() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state >> 11) / Double(1 << 53)
    }
}

/// Builds a seamless paper tile: low-frequency blotches + per-pixel grain.
func makePaperTexture(size: Int = 256) -> NSImage {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: size * 4, bitsPerPixel: 32)!
    let pixels = rep.bitmapData!

    var rng = XorShift64(state: 0x2545_F491_4F6C_DD1D)
    let cells = 8
    let cellSize = size / cells
    let grid = (0..<cells * cells).map { _ in rng.nextUnit() }

    func blotch(_ x: Int, _ y: Int) -> Double {
        let gx = x / cellSize, gy = y / cellSize
        let smooth = { (t: Double) in t * t * (3 - 2 * t) }
        let fx = smooth(Double(x % cellSize) / Double(cellSize))
        let fy = smooth(Double(y % cellSize) / Double(cellSize))
        let at = { (cx: Int, cy: Int) in grid[(cy % cells) * cells + (cx % cells)] }
        let top = at(gx, gy) * (1 - fx) + at(gx + 1, gy) * fx
        let bottom = at(gx, gy + 1) * (1 - fx) + at(gx + 1, gy + 1) * fx
        return top * (1 - fy) + bottom * fy
    }

    for y in 0..<size {
        for x in 0..<size {
            let shade = 0.88 + 0.08 * blotch(x, y) + 0.04 * rng.nextUnit()
            let i = (y * size + x) * 4
            pixels[i] = UInt8(245 * shade)
            pixels[i + 1] = UInt8(239 * shade)
            pixels[i + 2] = UInt8(226 * shade)
            pixels[i + 3] = 255
        }
    }

    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(rep)
    return image
}

// MARK: - Overlay

@MainActor
final class Overlay {
    private var windows: [NSWindow] = []
    private let texture = makePaperTexture()

    var opacity: CGFloat = 0.20 {
        didSet { windows.forEach { $0.alphaValue = opacity } }
    }
    var isEnabled = true {
        didSet { rebuild() }
    }

    /// One click-through window per screen.
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
            window.sharingType = .none
            window.alphaValue = opacity
            window.setFrame(screen.frame, display: false)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }
}

// MARK: - App

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlay = Overlay()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "📄"
        item.menu = makeMenu()
        statusItem = item

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        overlay.rebuild()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let toggle = NSMenuItem(title: "Enabled", action: #selector(toggle(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.state = .on
        menu.addItem(toggle)
        menu.addItem(.separator())

        for percent in [15, 20, 25, 30] {
            let item = NSMenuItem(
                title: "Opacity \(percent)%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            item.target = self
            item.tag = percent
            item.state = percent == 20 ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())

        menu.addItem(
            NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func toggle(_ sender: NSMenuItem) {
        overlay.isEnabled.toggle()
        sender.state = overlay.isEnabled ? .on : .off
    }

    @objc private func setOpacity(_ sender: NSMenuItem) {
        overlay.opacity = CGFloat(sender.tag) / 100
        for item in sender.menu?.items ?? [] where item.tag > 0 {
            item.state = item === sender ? .on : .off
        }
    }

    @objc private func screensChanged(_ notification: Notification) {
        overlay.rebuild()
    }
}

// Top-level code isn't main-actor isolated by default; we know it runs on the main thread.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
