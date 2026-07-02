import SwiftUI

enum AppTheme {
    enum Palette {
        static let forestDeep = Color(red: 0.03, green: 0.09, blue: 0.11)
        static let forestMid = Color(red: 0.07, green: 0.18, blue: 0.16)
        static let forestMuted = Color(red: 0.36, green: 0.52, blue: 0.39)
        static let navyInk = Color(red: 0.03, green: 0.06, blue: 0.12)
        static let cream = Color(red: 0.98, green: 0.92, blue: 0.82)
        static let creamMuted = Color(red: 0.83, green: 0.78, blue: 0.67)
        static let ember = Color(red: 1.00, green: 0.45, blue: 0.16)
        static let emberGold = Color(red: 1.00, green: 0.72, blue: 0.32)
        static let emberDark = Color(red: 0.70, green: 0.20, blue: 0.08)
        static let glassFill = Color.white.opacity(0.105)
        static let glassStroke = Color.white.opacity(0.18)
        static let shadow = Color.black.opacity(0.32)
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 28
    }

    enum Radius {
        static let card: CGFloat = 26
        static let control: CGFloat = 18
        static let pill: CGFloat = 999
    }
}
