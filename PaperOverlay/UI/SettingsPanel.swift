import SwiftUI

/// メニューバーのアイコンから開く設定パネル
struct SettingsPanel: View {
    @Bindable var overlay: OverlayController

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeader(overlay: overlay)

            VStack(alignment: .leading, spacing: 18) {
                StyleSection(selection: $overlay.style)
                OpacitySection(opacity: $overlay.opacity)
            }
            .disabled(!overlay.isEnabled)
            .opacity(overlay.isEnabled ? 1 : 0.45)
            .saturation(overlay.isEnabled ? 1 : 0)

            PanelFooter()
        }
        .padding(16)
        .frame(width: 320)
        .animation(.smooth(duration: 0.25), value: overlay.isEnabled)
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
        let percent = overlay.opacity.formatted(.percent.precision(.fractionLength(0)))
        return "\(overlay.style.title) · \(percent)"
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

// MARK: - Opacity

private struct OpacitySection: View {
    @Binding var opacity: Double

    private let presets: [Double] = [0.05, 0.10, 0.20, 0.30]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("濃さ")
                Spacer()
                Text(opacity, format: .percent.precision(.fractionLength(0)))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .contentTransition(.numericText(value: opacity))
                    .animation(.snappy, value: opacity)
            }

            Slider(value: $opacity, in: OverlaySettings.opacityRange) {
                Text("濃さ")
            } minimumValueLabel: {
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.secondary)
            }
            .labelsHidden()

            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { value in
                    PresetChip(value: value, isSelected: abs(opacity - value) < 0.005) {
                        withAnimation(.snappy) { opacity = value }
                    }
                }
            }
        }
    }
}

private struct PresetChip: View {
    let value: Double
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(value, format: .percent.precision(.fractionLength(0)))
                .font(.caption.monospacedDigit().weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background {
                    Capsule().fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.06)))
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Footer

private struct PanelFooter: View {
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
    SettingsPanel(overlay: OverlayController(store: SettingsStore(defaults: UserDefaults(suiteName: "preview")!)))
}
