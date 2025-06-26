import SwiftUI

enum AppTheme {
    enum Colors {
        // MARK: - Dynamic Colors

        static func neumorphicBase(for _: ColorScheme) -> Color {
            // Asset name should provide correct color for the scheme
            Color("neumorphicBaseColor")
        }

        static func accentLimeGreen(for _: ColorScheme) -> Color {
            // Asset name should provide correct color for the scheme
            Color("accentColorLimeGreen")
        }

        static var textPrimary: Color {
            // Asset name should provide correct color for the scheme
            Color("primaryAppText")
        }

        static var textSecondary: Color {
            // Asset name should provide correct color for the scheme
            Color("secondaryAppText")
        }

        // MARK: - Static Semantic Colors (if used elsewhere)

        static let textError: Color = .red
        static let textSuccess: Color = .init(red: 0.1, green: 0.6, blue: 0.2)
    }
}
