import SwiftUI

struct DSButton: View {
    enum Style {
        case primary
        case secondary
        case danger
    }

    let title: String
    let systemImage: String
    let style: Style
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.isEnabled) private var isEnvironmentEnabled

    init(
        title: String,
        systemImage: String,
        style: Style,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button {
            guard isInteractable else { return }
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DSColor.ink)
                } else {
                    Image(systemName: systemImage)
                }
                Text(isLoading ? "处理中…" : title)
            }
                .font(.appBody(16))
                .foregroundStyle(DSColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DSCornerRadius.button, style: .continuous)
                        .stroke(DSColor.outline, lineWidth: DSStroke.secondary)
                )
                .shadow(
                    color: DSColor.shadow.opacity(shadowOpacity),
                    radius: 0,
                    x: currentShadowOffset.width,
                    y: currentShadowOffset.height
                )
                .offset(x: isPressed && isInteractable ? 2 : 0, y: isPressed && isInteractable ? 2 : 0)
                .opacity(isInteractable ? 1 : 0.52)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractable)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isInteractable {
                        isPressed = true
                    }
                }
                .onEnded { _ in isPressed = false }
        )
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isPressed)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isLoading)
    }

    private var backgroundColor: Color {
        guard isInteractable else {
            return DSColor.surface
        }

        switch style {
        case .primary:
            return DSColor.yellow
        case .secondary:
            return DSColor.sky
        case .danger:
            return DSColor.coral
        }
    }

    private var isInteractable: Bool {
        isEnvironmentEnabled && !isDisabled && !isLoading
    }

    private var currentShadowOffset: CGSize {
        if !isInteractable {
            return .zero
        }
        return isPressed ? DSShadow.pressedOffset : CGSize(width: 4, height: 4)
    }

    private var shadowOpacity: Double {
        if !isInteractable {
            return 0
        }
        return isPressed ? DSShadow.pressedOpacity : 0.28
    }
}

struct DSIconButton: View {
    let systemImage: String
    var accessibilityLabel: String
    var fill: Color = DSColor.surface
    var size: CGFloat = 42
    var isLoading = false
    var action: () -> Void

    var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DSColor.ink)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: size * 0.4, weight: .black))
                }
            }
            .foregroundStyle(DSColor.ink)
            .frame(width: size, height: size)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: min(DSCornerRadius.smallCard, size * 0.32), style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: min(DSCornerRadius.smallCard, size * 0.32), style: .continuous)
                    .stroke(DSColor.outline, lineWidth: DSStroke.hairline)
            )
            .shadow(color: DSColor.shadow.opacity(isLoading ? 0 : DSShadow.weakOpacity), radius: 0, x: 3, y: 3)
            .opacity(isLoading ? 0.64 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(accessibilityLabel)
    }
}
