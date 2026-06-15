import SwiftUI

struct DSTextField: View {
    let title: String
    let systemImage: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .black))
                .frame(width: 24)
            TextField(title, text: $text)
                .font(.appBody())
                .textInputAutocapitalization(.never)
        }
        .foregroundStyle(DSColor.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DSColor.surface)
                .shadow(color: .white.opacity(0.75), radius: 6, x: -4, y: -4)
                .shadow(color: DSColor.ink.opacity(0.18), radius: 8, x: 5, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DSColor.ink, lineWidth: 2)
        )
    }
}
