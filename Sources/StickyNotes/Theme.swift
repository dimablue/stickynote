import SwiftUI

enum StickyTheme {
    static let ink = Color.primary
    static let mutedInk = Color.secondary
    static let hairline = Color(nsColor: .separatorColor)
    static let editorBackground = Color(nsColor: .textBackgroundColor)

    /// Controls carry no permanent background. They reveal a faint fill only
    /// while the pointer is over them.
    static let controlHover = Color.primary.opacity(0.08)
    static let controlCornerRadius: CGFloat = 5
    static let surfaceCornerRadius: CGFloat = 13

    /// Icon-button hit target and glyph size. The hit target stays comfortably
    /// larger than the glyph so the controls remain easy to click.
    static let controlSize: CGFloat = 17
    static let controlSymbolSize: CGFloat = 9
}

/// Editor body text size, shared by the Floating Stack and the Library so text
/// stays the same size wherever a note is opened. Stored as `Double` because
/// that is what `@AppStorage` supports.
enum EditorFont {
    static let minimum: Double = 11
    static let maximum: Double = 28
    static let standard: Double = 16
    static let step: Double = 1

    static func clamped(_ size: Double) -> Double {
        guard size.isFinite else { return standard }
        return min(max(size, minimum), maximum)
    }
}

struct IconButton: View {
    let systemName: String
    let label: String
    var isEnabled = true
    var size: CGFloat = StickyTheme.controlSize
    var symbolSize: CGFloat = StickyTheme.controlSymbolSize
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .frame(width: size, height: size)
                .background(ControlHoverFill(isActive: isHovering && isEnabled))
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .controlSize(.mini)
        .foregroundStyle(.secondary)
        .opacity(isEnabled ? 1 : 0.35)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// A destructive button that confirms in place: the first click swaps the icon
/// for “Sure?”, the second click performs the action. Disarms itself after a
/// few seconds of inactivity, and whenever `resetKey` changes.
struct ConfirmingDeleteButton: View {
    let systemName: String
    let label: String
    var confirmTitle = "Sure?"
    var size: CGFloat = StickyTheme.controlSize
    var symbolSize: CGFloat = StickyTheme.controlSymbolSize
    var resetKey: UUID?
    var action: () -> Void

    @State private var isArmed = false
    @State private var isHovering = false
    @State private var disarmTask: Task<Void, Never>?

    var body: some View {
        Button {
            if isArmed {
                disarm()
                action()
            } else {
                arm()
            }
        } label: {
            label(for: isArmed)
                .frame(height: size)
                .background(background)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .controlSize(.mini)
        .foregroundStyle(isArmed ? Color.red : Color.secondary)
        .onHover { isHovering = $0 }
        .help(isArmed ? "Click again to delete" : label)
        .accessibilityLabel(isArmed ? "Confirm \(label.lowercased())" : label)
        .accessibilityHint(isArmed ? "" : "Asks for confirmation before deleting")
        .onChange(of: resetKey) { _, _ in disarm() }
        .onDisappear { disarm() }
    }

    @ViewBuilder
    private func label(for armed: Bool) -> some View {
        if armed {
            Text(confirmTitle)
                .font(.system(size: symbolSize, weight: .semibold))
                .fixedSize()
                .padding(.horizontal, 5)
        } else {
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .frame(width: size)
        }
    }

    @ViewBuilder
    private var background: some View {
        if isArmed {
            RoundedRectangle(
                cornerRadius: StickyTheme.controlCornerRadius,
                style: .continuous
            )
            .fill(Color.red.opacity(0.14))
        } else {
            ControlHoverFill(isActive: isHovering)
        }
    }

    private func arm() {
        isArmed = true
        disarmTask?.cancel()
        disarmTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            isArmed = false
        }
    }

    private func disarm() {
        disarmTask?.cancel()
        disarmTask = nil
        isArmed = false
    }
}

private struct ControlHoverFill: View {
    let isActive: Bool

    var body: some View {
        RoundedRectangle(
            cornerRadius: StickyTheme.controlCornerRadius,
            style: .continuous
        )
        .fill(isActive ? StickyTheme.controlHover : Color.clear)
    }
}

/// The Floating Stack's card: a solid, appearance-adaptive surface with a
/// hairline rim so its edge stays legible against any desktop backdrop. The
/// window supplies the drop shadow.
private struct StickySurface: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background(StickyTheme.editorBackground)
            .clipShape(shape)
            .overlay(shape.strokeBorder(StickyTheme.hairline, lineWidth: 1))
    }
}

extension View {
    func stickySurface(
        cornerRadius: CGFloat = StickyTheme.surfaceCornerRadius
    ) -> some View {
        modifier(StickySurface(cornerRadius: cornerRadius))
    }
}

extension Date {
    var compactEditedLabel: String {
        "Edited " + formatted(.dateTime.month(.abbreviated).day())
    }

    var fullCreatedLabel: String {
        "Created " + formatted(.dateTime.month(.wide).day().year())
    }

    var fullEditedLabel: String {
        "Last edited " + formatted(.dateTime.month(.wide).day().year())
    }

    var shortListLabel: String {
        formatted(.dateTime.month(.abbreviated).day())
    }
}
