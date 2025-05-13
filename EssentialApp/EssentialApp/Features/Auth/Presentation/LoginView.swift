
import EssentialFeed
import SwiftUI

public struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel

    public init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            TextField("Usuario", text: $viewModel.username)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Contraseña", text: $viewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if viewModel.isLoginBlocked {
                blockedView()
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else if viewModel.loginSuccess {
                successView(message: "¡Bienvenido!")
            } else {
                loginButton
            }
        }
        .padding()
    }

    private var loginButton: some View {
        Button("Iniciar sesión") {
            Task { await viewModel.login() }
        }
    }

    private func blockedView() -> some View {
        VStack {
            Image(systemName: "lock.fill")
                .foregroundColor(.red)
            Text("Too many failed attempts. Please try again later.")
        }
    }

    private func successView(message: String) -> some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
        }
    }

    private func errorView(message: String) -> some View {
        VStack {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
            Text(message)
        }
    }
}
