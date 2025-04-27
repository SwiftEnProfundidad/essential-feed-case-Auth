import SwiftUI

public struct PasswordRecoveryScreen: View {
    @ObservedObject var viewModel: PasswordRecoverySwiftUIViewModel

    public init(viewModel: PasswordRecoverySwiftUIViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $viewModel.email)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Recuperar contraseña") {
                viewModel.recoverPassword()
            }
            .modifier(BorderedProminentIfAvailable())
        }
        .padding()
        .alert(isPresented: $viewModel.showingFeedback) {
            Alert(
                title: Text(viewModel.feedbackTitle),
                message: Text(viewModel.feedbackMessage),
                dismissButton: .default(Text("OK"), action: viewModel.onFeedbackDismiss)
            )
        }
    }
}
