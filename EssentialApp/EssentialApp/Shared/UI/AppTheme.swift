import SwiftUI

enum AppTheme {
    enum Colors {
        // MARK: - Dark Mode Specific Colors (based on User's 'Any Appearance' in Assets)

        private static let darkSchemeNeumorphicBase = Color(
            red: 45 / 255, green: 47 / 255, blue: 52 / 255
        )
        private static let darkSchemeAccentLimeGreen = Color(
            red: 175 / 255, green: 255 / 255, blue: 51 / 255
        )

        // MARK: - Light Mode Specific Colors

        private static let lightSchemeNeumorphicBase = Color(
            red: 255 / 255, green: 255 / 255, blue: 255 / 255
        )
        private static let lightSchemeAccentLimeGreen = Color("accentColorLimeGreen")

        // MARK: - Dynamic Colors

        static func neumorphicBase(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? darkSchemeNeumorphicBase : lightSchemeNeumorphicBase
        }

        static func accentLimeGreen(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? darkSchemeAccentLimeGreen : lightSchemeAccentLimeGreen
        }

        static var textPrimary: Color {
            Color(UIColor.label)
        }

        static var textSecondary: Color {
            Color(UIColor.secondaryLabel)
        }

        // MARK: - Static Semantic Colors (if used elsewhere)

        static let textError: Color = .red
        static let textSuccess: Color = .init(red: 0.1, green: 0.6, blue: 0.2)
    }
}
