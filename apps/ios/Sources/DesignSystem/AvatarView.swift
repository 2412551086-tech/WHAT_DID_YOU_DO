import SwiftUI
import UIKit

enum AvatarPresentation {
    case sticker
    case quiet
    case flat
}

struct AvatarView: View {
    let avatarKey: String?
    let fallbackText: String
    var size: CGFloat = 48
    var presentation: AvatarPresentation = .sticker

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
        .overlay(Circle().stroke(strokeColor, lineWidth: strokeWidth))
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: shadowOffset.width,
            y: shadowOffset.height
        )
        .accessibilityLabel("头像 \(fallbackText)")
    }

    private var strokeColor: Color {
        switch presentation {
        case .sticker:
            return DSColor.ink
        case .quiet:
            return DSColor.subtleStroke
        case .flat:
            return .clear
        }
    }

    private var strokeWidth: CGFloat {
        switch presentation {
        case .sticker:
            return max(1.5, size * 0.045)
        case .quiet:
            return 1
        case .flat:
            return 0
        }
    }

    private var shadowColor: Color {
        switch presentation {
        case .sticker:
            return DSColor.ink.opacity(0.22)
        case .quiet:
            return DSColor.ink.opacity(0.08)
        case .flat:
            return .clear
        }
    }

    private var shadowRadius: CGFloat {
        presentation == .quiet ? 5 : 0
    }

    private var shadowOffset: CGSize {
        switch presentation {
        case .sticker:
            return CGSize(width: 3, height: 3)
        case .quiet:
            return CGSize(width: 0, height: 2)
        case .flat:
            return .zero
        }
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
