import SwiftUI

enum WidgetTheme {
    enum Palette {
        static let cream = Color(red: 1.0, green: 0.94, blue: 0.82)
        static let creamMuted = Color(red: 0.84, green: 0.78, blue: 0.66)
        static let ember = Color(red: 1.0, green: 0.38, blue: 0.12)
        static let emberGold = Color(red: 1.0, green: 0.70, blue: 0.27)
        static let forest = Color(red: 0.16, green: 0.33, blue: 0.23)
        static let forestGlow = Color(red: 0.42, green: 0.64, blue: 0.43)
        static let navyInk = Color(red: 0.03, green: 0.07, blue: 0.12)
        static let glass = Color.white.opacity(0.12)
        static let glassStroke = Color.white.opacity(0.18)
    }

    enum Radius {
        static let panel: CGFloat = 22
        static let badge: CGFloat = 14
    }
}
