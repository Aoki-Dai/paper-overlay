import SwiftUI

/// メニューバーのアイコンから開く設定パネル
struct SettingsPanel: View {
    @Bindable var overlay: OverlayController
    @AppStorage(UIPreferences.showRecommendedKey) private var showRecommended = true
    @AppStorage(UIPreferences.showPresetsKey) private var showPresets = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeader(overlay: overlay)

            VStack(alignment: .leading, spacing: 18) {
                StyleSection(selection: $overlay.style)
                IntensitySection(
                    intensity: $overlay.intensity,
                    showsRecommended: showRecommended,
                    showsPresets: showPresets)
                // モニターが 1 台なら選ぶものがないので出さない
                if overlay.displays.count > 1 {
                    DisplaySection(overlay: overlay)
                        .transition(.opacity)
                }
            }
            .disabled(!overlay.isEnabled)
            .opacity(overlay.isEnabled ? 1 : 0.45)
            .saturation(overlay.isEnabled ? 1 : 0)

            if showRecommended {
                RecommendedButton(overlay: overlay)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            PanelFooter()
        }
        .padding(16)
        .frame(width: 320)
        .animation(.smooth(duration: 0.25), value: overlay.isEnabled)
        .animation(.smooth(duration: 0.25), value: showRecommended)
        .animation(.smooth(duration: 0.25), value: showPresets)
    }
}

// MARK: - Header

private struct PanelHeader: View {
    @Bindable var overlay: OverlayController

    var body: some View {
        HStack(spacing: 12) {
            AppBadge(isEnabled: overlay.isEnabled)

            VStack(alignment: .leading, spacing: 2) {
                Text("Paper Overlay")
                    .font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: status)
            }

            Spacer(minLength: 8)

            Toggle("オーバーレイを表示", isOn: $overlay.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private var status: String {
        guard overlay.isEnabled else { return "オフ" }
        let percent = overlay.intensity.formatted(.percent.precision(.fractionLength(0)))
        let displays = overlay.displays.count > 1
            ? " · \(overlay.shownDisplayCount)/\(overlay.displays.count) 画面"
            : ""
        // 個別に設定したモニターは上の値と違う見た目なので、その台数も添える
        let customized = overlay.customizedDisplayCount > 0
            ? "（個別 \(overlay.customizedDisplayCount) 台）"
            : ""
        return "\(overlay.style.title) · \(percent)\(displays)\(customized)"
    }
}

private struct AppBadge: View {
    let isEnabled: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(
                isEnabled
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(red: 0.93, green: 0.80, blue: 0.62), Color(red: 0.78, green: 0.60, blue: 0.42)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.secondary.opacity(0.25))
            )
            .overlay {
                Image(systemName: isEnabled ? "doc.plaintext.fill" : "doc.plaintext")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 34, height: 34)
            .shadow(color: .black.opacity(isEnabled ? 0.15 : 0), radius: 3, y: 1)
    }
}

// MARK: - Style

private struct StyleSection: View {
    @Binding var selection: TextureStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("スタイル")
            HStack(spacing: 10) {
                ForEach(TextureStyle.allCases) { style in
                    StyleCard(style: style, isSelected: style == selection) {
                        withAnimation(.snappy) { selection = style }
                    }
                }
            }
        }
    }
}

private struct StyleCard: View {
    let style: TextureStyle
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                TextureSwatch(style: style)

                HStack(alignment: .top, spacing: 4) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(style.title)
                            .font(.callout.weight(.medium))
                        Text(style.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(isHovered ? 0.07 : 0.04))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .accessibilityLabel(style.title)
        .accessibilityHint(style.subtitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 白と黒の地にテクスチャを重ねた見本。実際の重なり方の違いが一目でわかる
private struct TextureSwatch: View {
    let style: TextureStyle

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Color.white
                Color(white: 0.1)
            }
            Image(nsImage: TexturePreviews.image(for: style))
                .resizable(resizingMode: .tile)
                .opacity(0.4)
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
        }
    }
}

/// 見本用の小さなタイル。スタイルごとに 1 回だけ作る
@MainActor
private enum TexturePreviews {
    private static var cache: [TextureStyle: NSImage] = [:]

    static func image(for style: TextureStyle) -> NSImage {
        if let image = cache[style] { return image }
        let image = TextureGenerator.makeTile(pixelSize: 128, scale: 2, style: style)
        cache[style] = image
        return image
    }
}

// MARK: - Intensity

/// 強さ（0〜100%）。実際の不透明度 0〜30% を 0〜100% に引き伸ばして見せる
private struct IntensitySection: View {
    @Binding var intensity: Double
    let showsRecommended: Bool
    let showsPresets: Bool

    private let presets: [Double] = [0.20, 0.40, 0.60, 0.80, 1.0]
    private var recommended: Double { OverlaySettings.intensity(forOpacity: OverlaySettings.recommended.opacity) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("強さ")
                Spacer()
                Text(intensity, format: .percent.precision(.fractionLength(0)))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .contentTransition(.numericText(value: intensity))
                    .animation(.snappy, value: intensity)
            }

            Slider(value: $intensity, in: 0...1) {
                Text("強さ")
            } minimumValueLabel: {
                Text("0").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("100").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            .labelsHidden()

            if showsPresets {
                presetRow
                    .transition(.opacity)
            }
        }
    }

    private var presetRow: some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.self) { value in
                PresetChip(
                    value: value,
                    isSelected: abs(intensity - value) < 0.005,
                    isRecommended: showsRecommended && abs(value - recommended) < 0.005
                ) {
                    withAnimation(.snappy) { intensity = value }
                }
            }
        }
    }
}

private struct PresetChip: View {
    let value: Double
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void

    /// 高さの半分で角を丸めた長方形（Capsule と同じ見た目）
    private let chipShape = RoundedRectangle(cornerRadius: 100, style: .circular)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if isRecommended {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(Color.warmAccent))
                }
                Text(value, format: .percent.precision(.fractionLength(0)))
            }
            .font(.caption.monospacedDigit().weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .background {
                ZStack {
                    chipShape.fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.06)))
                    chipShape
                        .inset(by: 0.5)
                        .stroke(Color.warmAccent.opacity(isRecommended && !isSelected ? 0.6 : 0), lineWidth: 1)
                }
            }
            .contentShape(chipShape)
        }
        .buttonStyle(.plain)
        .help(isRecommended ? "おすすめの強さ" : "")
    }
}

// MARK: - Displays

private struct DisplaySection: View {
    let overlay: OverlayController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("モニター")
            VStack(spacing: 0) {
                ForEach(Array(overlay.displays.enumerated()), id: \.element.id) { index, display in
                    if index > 0 {
                        Divider().padding(.leading, 36)
                    }
                    DisplayRow(overlay: overlay, display: display)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
        }
    }
}

/// パネル用の 1 行：アイコンと名前を左、スイッチを右にそろえる
private struct DisplayRow: View {
    let overlay: OverlayController
    let display: DisplayInfo

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(display.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(overlay.isCustomized(display) ? AnyShapeStyle(Color.warmAccent) : AnyShapeStyle(.secondary))
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 8)
            Toggle(display.name, isOn: Binding(
                get: { overlay.isShown(on: display) },
                set: { isShown in withAnimation(.snappy) { overlay.setShown(isShown, on: display) } }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    /// 個別に設定していれば、その内容。そうでなければ全体の設定に従うことを示す
    private var detail: String {
        guard overlay.isShown(on: display) else { return "表示しない" }
        guard overlay.isCustomized(display) else { return "全体の設定" }
        let percent = overlay.intensity(for: display).formatted(.percent.precision(.fractionLength(0)))
        return "個別：\(overlay.style(for: display).title) · \(percent)"
    }
}

// MARK: - Recommended

/// おすすめの設定（OverlaySettings.recommended）を 1 回の操作でまとめて適用する
private struct RecommendedButton: View {
    let overlay: OverlayController

    var body: some View {
        let isApplied = overlay.isRecommended
        let recommended = OverlaySettings.recommended
        let percent = OverlaySettings.intensity(forOpacity: recommended.opacity)
            .formatted(.percent.precision(.fractionLength(0)))
        let summary = "\(recommended.style.title) · 強さ \(percent)"
        Button {
            withAnimation(.snappy) { overlay.applyRecommended() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isApplied ? "checkmark.seal.fill" : "sparkles")
                    .foregroundStyle(Color.warmAccent)
                    .contentTransition(.symbolEffect(.replace))
                Text(isApplied ? "おすすめ設定で表示中" : "おすすめ設定にする")
                    .font(.callout.weight(.medium))
                Spacer(minLength: 4)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.warmAccent.opacity(isApplied ? 0.08 : 0.16))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.warmAccent.opacity(isApplied ? 0.2 : 0.45))
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isApplied)
    }
}

// MARK: - Footer

private struct PanelFooter: View {
    @Environment(\.openSettings) private var openSettings
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 10) {
            Divider()
            HStack {
                Text("v\(version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    openSettings()
                    // Dock に出ないアプリなので、前面に出さないと設定ウインドウが後ろに隠れる
                    NSApplication.shared.activate()
                } label: {
                    Label("設定…", systemImage: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(",")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("終了", systemImage: "power")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("q")
            }
        }
    }
}

// MARK: - Parts

private struct SectionTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

extension Color {
    /// アイコンと同系色の、紙らしい暖かいアクセント
    static let warmAccent = Color(red: 0.80, green: 0.58, blue: 0.36)
}

extension TextureStyle {
    var title: String {
        switch self {
        case .paper: "紙"
        case .ePaper: "電子ペーパー"
        }
    }

    var subtitle: String {
        switch self {
        case .paper: "繊維のある温かい質感"
        case .ePaper: "落ち着いた無彩色"
        }
    }
}

#Preview {
    SettingsPanel(overlay: OverlayController(store: SettingsStore(defaults: InMemorySettingsStorage())))
}
