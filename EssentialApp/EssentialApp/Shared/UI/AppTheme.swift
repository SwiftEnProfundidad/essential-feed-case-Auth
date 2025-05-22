import SwiftUI

enum AppTheme {
    enum Colors {
        static let neumorphicBase = Color("neumorphicBaseColor")
        static let accentLimeGreen = Color("accentColorLimeGreen")
        static let textPrimary = Color("primaryAppText")
        static let textSecondary = Color("secondaryAppText")
        static let textError: Color = .red
        static let textSuccess: Color = .init(red: 0.1, green: 0.6, blue: 0.2)
    }
}
