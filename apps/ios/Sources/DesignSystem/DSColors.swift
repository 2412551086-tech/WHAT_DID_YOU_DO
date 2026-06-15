import SwiftUI

enum DSColor {
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

extension Font {
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
