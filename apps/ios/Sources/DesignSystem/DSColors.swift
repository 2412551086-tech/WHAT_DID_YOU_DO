import SwiftUI

enum DSColor {
    static let pageBackground = background
    static let brand = yellow
    static let accent = sky
    static let warning = coral
    static let success = mint
    static let cardBackground = surface
    static let outline = ink
    static let secondaryText = mutedInk

    static let background = Color(red: 0.95, green: 0.93, blue: 0.86)
    static let surface = Color(red: 1.00, green: 0.98, blue: 0.91)
    static let ink = Color(red: 0.10, green: 0.10, blue: 0.09)
    static let mutedInk = Color(red: 0.34, green: 0.33, blue: 0.29)
    static let yellow = Color(red: 1.00, green: 0.82, blue: 0.22)
    static let coral = Color(red: 1.00, green: 0.43, blue: 0.34)
    static let mint = Color(red: 0.47, green: 0.86, blue: 0.66)
    static let sky = Color(red: 0.46, green: 0.73, blue: 1.00)
    static let lavender = Color(red: 0.75, green: 0.63, blue: 1.00)
    static let clay = Color(red: 0.83, green: 0.64, blue: 0.45)
}

enum DSSpacing {
    static let page: CGFloat = 20
    static let cardPadding: CGFloat = 18
    static let component: CGFloat = 14
    static let list: CGFloat = 12
    static let tight: CGFloat = 8
}

enum DSCornerRadius {
    static let largeCard: CGFloat = 22
    static let smallCard: CGFloat = 16
    static let button: CGFloat = 14
    static let badge: CGFloat = 999
    static let avatar: CGFloat = 999
}

enum DSStroke {
    static let primary: CGFloat = 2.5
    static let secondary: CGFloat = 2
    static let hairline: CGFloat = 1.5
}

enum DSShadow {
    static let hardOffset = CGSize(width: 5, height: 5)
    static let weakOffset = CGSize(width: 3, height: 3)
    static let pressedOffset = CGSize(width: 2, height: 2)
    static let hardOpacity = 0.24
    static let weakOpacity = 0.16
    static let pressedOpacity = 0.08
}

extension Font {
    static var dsHeroTitle: Font { .appTitle(38) }
    static var dsPageTitle: Font { .appTitle(34) }
    static var dsCardTitle: Font { .appHeadline(22) }
    static var dsBody: Font { .appBody(16) }
    static var dsCaption: Font { .appBody(13) }
    static var dsLabel: Font { .appBody(12) }

    static func appTitle(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func appHeadline(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func appBody(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}
