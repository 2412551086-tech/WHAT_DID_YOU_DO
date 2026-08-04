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

    // Quiet functional surfaces used by the high-fidelity dashboard direction.
    static let quietBackground = Color(red: 0.98, green: 0.97, blue: 0.94)
    static let pureSurface = Color(red: 1.00, green: 1.00, blue: 1.00)
    static let subtleStroke = Color(red: 0.89, green: 0.88, blue: 0.85)
    static let infoBlue = Color(red: 0.08, green: 0.55, blue: 0.98)
    static let accentOrange = Color(red: 1.00, green: 0.42, blue: 0.08)
    static let redSoft = Color(red: 1.00, green: 0.90, blue: 0.88)
    static let choreYellowSurface = Color(red: 1.00, green: 0.98, blue: 0.90)
    static let choreBlueSurface = Color(red: 0.93, green: 0.97, blue: 1.00)
    static let choreMintSurface = Color(red: 0.93, green: 0.99, blue: 0.97)
    static let chorePinkSurface = Color(red: 1.00, green: 0.94, blue: 0.95)

    // Shared warm floating surfaces used by quiet dashboard-style screens.
    static let floatingPageBackground = Color(red: 1.00, green: 0.976, blue: 0.91)
    static let floatingSurface = Color.white.opacity(0.88)
    static let floatingStroke = Color(red: 0.85, green: 0.84, blue: 0.81).opacity(0.72)
    static let floatingHighlight = Color.white.opacity(0.72)
    static let floatingDivider = Color(red: 0.91, green: 0.89, blue: 0.85)
    static let floatingPrimaryText = Color(red: 0.09, green: 0.09, blue: 0.08)
    static let floatingSecondaryText = Color(red: 0.41, green: 0.40, blue: 0.37)
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
    static let softRadius: CGFloat = 14
    static let softYOffset: CGFloat = 6
    static let softOpacity = 0.08
    static let floatingPrimaryRadius: CGFloat = 23
    static let floatingPrimaryYOffset: CGFloat = 10
    static let floatingPrimaryOpacity = 0.11
    static let floatingContactRadius: CGFloat = 5
    static let floatingContactYOffset: CGFloat = 3
    static let floatingContactOpacity = 0.055
    static let floatingSecondaryRadius: CGFloat = 20
    static let floatingSecondaryYOffset: CGFloat = 7
    static let floatingSecondaryOpacity = 0.055
}

enum DSFont {
    static let functionalPageTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let functionalSectionTitle = Font.system(size: 27, weight: .bold, design: .default)
    static let functionalCardTitle = Font.system(size: 16, weight: .semibold, design: .default)
    static let functionalBody = Font.system(size: 14, weight: .regular, design: .default)
    static let functionalCaption = Font.system(size: 13, weight: .regular, design: .default)
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
