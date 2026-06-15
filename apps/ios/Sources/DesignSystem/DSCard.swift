import SwiftUI

struct DSCard<Content: View>: View {
    let fill: Color
    let content: Content

    init(fill: Color = DSColor.surface, @ViewBuilder content: () -> Content) {
        self.fill = fill
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
                    .shadow(color: .white.opacity(0.72), radius: 8, x: -5, y: -5)
                    .shadow(color: DSColor.ink.opacity(0.24), radius: 0, x: 5, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DSColor.ink, lineWidth: 2.5)
            )
    }
}

struct DSMetricPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        DSCard(fill: color) {
            VStack(alignment: .leading, spacing: 6) {
                Text(value)
                    .font(.appHeadline(24))
                    .foregroundStyle(DSColor.ink)
                Text(title)
                    .font(.appBody(13))
                    .foregroundStyle(DSColor.mutedInk)
            }
        }
    }
}
