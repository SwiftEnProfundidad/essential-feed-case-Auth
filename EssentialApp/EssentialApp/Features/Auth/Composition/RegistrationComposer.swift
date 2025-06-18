import SwiftUI
import UIKit

public enum RegistrationComposer {
    @MainActor public static func registrationViewController() -> UIViewController {
        let viewModel = RegistrationViewModel()
        let registrationView = RegistrationView(viewModel: viewModel)
        return UIHostingController(rootView: registrationView)
    }
}

private struct RegistrationPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Registration Screen")
                .font(.largeTitle)
                .padding()

            Text("Coming Soon...")
                .font(.title2)
                .foregroundColor(.secondary)

            Button("Close") {
                dismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}
