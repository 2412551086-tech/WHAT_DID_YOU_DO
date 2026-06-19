import SwiftUI
import UIKit

struct AvatarView: View {
    let avatarKey: String?
    let fallbackText: String
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let avatarKey, UIImage(named: avatarKey) != nil {
                Image(avatarKey)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    fallbackColor
                    Text(fallbackEmoji)
                        .font(.system(size: size * 0.45))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(DSColor.ink, lineWidth: max(1.5, size * 0.045)))
        .shadow(color: DSColor.ink.opacity(0.22), radius: 0, x: 3, y: 3)
        .accessibilityLabel("头像 \(fallbackText)")
    }

    private var fallbackEmoji: String {
        switch avatarKey {
        case "avatar_01": return "😎"
        case "avatar_02": return "🥳"
        case "avatar_03": return "🧹"
        case "avatar_04": return "🍳"
        case "avatar_05": return "🌱"
        case "avatar_06": return "✨"
        default: return String(fallbackText.prefix(1))
        }
    }

    private var fallbackColor: Color {
        switch avatarKey {
        case "avatar_01": return DSColor.yellow
        case "avatar_02": return DSColor.mint
        case "avatar_03": return DSColor.sky
        case "avatar_04": return DSColor.coral
        case "avatar_05": return DSColor.lavender
        case "avatar_06": return DSColor.clay
        default: return DSColor.surface
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarView(avatarKey: "avatar_01", fallbackText: "我", size: 58)
        AvatarView(avatarKey: "avatar_05", fallbackText: "家", size: 58)
        AvatarView(avatarKey: nil, fallbackText: "新", size: 58)
    }
    .padding(24)
    .background(DSColor.background)
}
