import EssentialFeed
import SwiftUI

public struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @State private var showingPasswordRecovery = false

    public init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            TextField("Username", text: $viewModel.username)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
            Button("Login") {
                Task {
                    await viewModel.login()
                }
            }
            .modifier(BorderedProminentIfAvailable())
            Button("Forgot your password?") {
                showingPasswordRecovery = true
            }
            .font(.footnote)
        }
        .padding()
        .sheet(isPresented: $showingPasswordRecovery) {
            PasswordRecoveryComposer.passwordRecoveryViewScreen()
        }
        .alert(isPresented: $viewModel.loginSuccess) {
            Alert(
                title: Text("Login Successful"),
                message: Text("Welcome, \(viewModel.username)!"),
                dismissButton: .default(Text("OK"), action: {
                    viewModel.onSuccessAlertDismissed()
                })
            )
        }
        .onAppear {}
    }
}

public protocol LoginSuccessView: AnyObject {
    func showLoginSuccess()
}

public protocol LoginErrorClearingView: AnyObject {
    func clearErrorMessages()
}
