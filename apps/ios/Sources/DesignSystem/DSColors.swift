import SwiftUI
import UIKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    static func resolve(_ rawValue: String) -> AppAppearance {
        AppAppearance(rawValue: rawValue) ?? .system
    }
}

enum DSColor {
    static let pageBackground = background
    static let brand = yellow
    static let accent = sky
    static let warning = coral
    static let success = mint
    static let cardBackground = surface
    static let outline = adaptive(
        light: (0.10, 0.10, 0.09, 1),
        dark: (0.36, 0.35, 0.31, 1)
    )
    static let secondaryText = mutedInk

    static let background = adaptive(
        light: (0.95, 0.93, 0.86, 1),
        dark: (0.095, 0.095, 0.082, 1)
    )
    static let surface = adaptive(
        light: (1.00, 0.98, 0.91, 1),
        dark: (0.16, 0.155, 0.135, 1)
    )
    static let ink = adaptive(
        light: (0.10, 0.10, 0.09, 1),
        dark: (1.00, 0.97, 0.90, 1)
    )
    static let mutedInk = adaptive(
        light: (0.34, 0.33, 0.29, 1),
        dark: (0.72, 0.70, 0.65, 1)
    )
    static let yellow = adaptive(
        light: (1.00, 0.82, 0.22, 1),
        dark: (0.48, 0.38, 0.10, 1)
    )
    static let coral = adaptive(
        light: (1.00, 0.43, 0.34, 1),
        dark: (0.48, 0.22, 0.19, 1)
    )
    static let mint = adaptive(
        light: (0.47, 0.86, 0.66, 1),
        dark: (0.16, 0.37, 0.27, 1)
    )
    static let sky = adaptive(
        light: (0.46, 0.73, 1.00, 1),
        dark: (0.15, 0.34, 0.50, 1)
    )
    static let lavender = adaptive(
        light: (0.75, 0.63, 1.00, 1),
        dark: (0.31, 0.27, 0.44, 1)
    )
    static let clay = adaptive(
        light: (0.83, 0.64, 0.45, 1),
        dark: (0.39, 0.29, 0.21, 1)
    )

    // Quiet functional surfaces used by the high-fidelity dashboard direction.
    static let quietBackground = adaptive(
        light: (0.98, 0.97, 0.94, 1),
        dark: (0.095, 0.095, 0.082, 1)
    )
    static let pureSurface = adaptive(
        light: (1.00, 1.00, 1.00, 1),
        dark: (0.145, 0.14, 0.12, 1)
    )
    static let subtleStroke = adaptive(
        light: (0.89, 0.88, 0.85, 1),
        dark: (0.27, 0.26, 0.23, 1)
    )
    static let infoBlue = adaptive(
        light: (0.08, 0.55, 0.98, 1),
        dark: (0.34, 0.68, 1.00, 1)
    )
    static let accentOrange = adaptive(
        light: (1.00, 0.42, 0.08, 1),
        dark: (1.00, 0.56, 0.25, 1)
    )
    static let redSoft = adaptive(
        light: (1.00, 0.90, 0.88, 1),
        dark: (0.30, 0.17, 0.15, 1)
    )
    static let choreYellowSurface = adaptive(
        light: (1.00, 0.98, 0.90, 1),
        dark: (0.25, 0.22, 0.13, 1)
    )
    static let choreBlueSurface = adaptive(
        light: (0.93, 0.97, 1.00, 1),
        dark: (0.13, 0.20, 0.27, 1)
    )
    static let choreMintSurface = adaptive(
        light: (0.93, 0.99, 0.97, 1),
        dark: (0.13, 0.23, 0.19, 1)
    )
    static let chorePinkSurface = adaptive(
        light: (1.00, 0.94, 0.95, 1),
        dark: (0.27, 0.16, 0.18, 1)
    )

    // Shared warm floating surfaces used by quiet dashboard-style screens.
    static let floatingPageBackground = adaptive(
        light: (1.00, 0.976, 0.91, 1),
        dark: (0.095, 0.095, 0.082, 1)
    )
    static let floatingSurface = adaptive(
        light: (1.00, 1.00, 1.00, 0.88),
        dark: (0.17, 0.165, 0.145, 0.94)
    )
    static let floatingStroke = adaptive(
        light: (0.85, 0.84, 0.81, 0.72),
        dark: (0.31, 0.30, 0.27, 0.82)
    )
    static let floatingHighlight = adaptive(
        light: (1.00, 1.00, 1.00, 0.72),
        dark: (1.00, 0.97, 0.90, 0.08)
    )
    static let floatingDivider = adaptive(
        light: (0.91, 0.89, 0.85, 1),
        dark: (0.25, 0.24, 0.21, 1)
    )
    static let floatingPrimaryText = ink
    static let floatingSecondaryText = mutedInk

    static let shadow = Color.black
    static let raisedHighlight = adaptive(
        light: (1.00, 1.00, 1.00, 0.72),
        dark: (1.00, 0.97, 0.90, 0.06)
    )
    static let selectionSurface = adaptive(
        light: (0.94, 0.93, 0.89, 1),
        dark: (0.22, 0.21, 0.18, 1)
    )

    private static func adaptive(
        light: (CGFloat, CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: value.0,
                green: value.1,
                blue: value.2,
                alpha: value.3
            )
        })
    }
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
