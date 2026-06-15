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
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.appBody(16))
                .foregroundStyle(DSColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DSColor.ink, lineWidth: 2)
                )
                .shadow(color: DSColor.ink.opacity(isPressed ? 0.08 : 0.28), radius: 0, x: isPressed ? 2 : 4, y: isPressed ? 2 : 4)
                .offset(x: isPressed ? 2 : 0, y: isPressed ? 2 : 0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isPressed)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            DSColor.yellow
        case .secondary:
            DSColor.sky
        case .danger:
            DSColor.coral
        }
    }
}
