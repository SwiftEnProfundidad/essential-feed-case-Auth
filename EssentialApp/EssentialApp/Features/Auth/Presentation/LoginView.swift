import EssentialFeed
import SwiftUI

public struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel

    public init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        Text("MiApp")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.bottom, 30)

                        VStack(spacing: 15) {
                            TextField("Usuario", text: $viewModel.username, onEditingChanged: { isEditing in
                                if isEditing {
                                    viewModel.userDidInitiateEditing()
                                }
                            })
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                            TextField("Contraseña", text: $viewModel.password)
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)

                        switch viewModel.viewState {
                        case .idle:
                            loginControls
                                .padding(.top, 10)
                        case .blocked:
                            blockedView()
                                .padding(.top, 10)
                        case let .error(message):
                            errorView(message: message)
                                .padding(.top, 10)
                        case let .success(message):
                            successView(message: message)
                                .padding(.top, 10)
                        }
                    }
                    .padding()
                    .frame(minHeight: geometry.size.height)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
    }

    private var loginButton: some View {
        Button("Iniciar sesión") {
            Task { await viewModel.login() }
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue)
        .cornerRadius(10)
        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 5)
    }

    private var loginControls: some View {
        VStack(spacing: 15) {
            loginButton
            Button("¿Olvidaste tu contraseña?") {
                viewModel.handleRecoveryTap()
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal)
    }

    private func blockedView() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundColor(.red)
            Text("Too many failed attempts. Please try again later.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func successView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundColor(.green)
            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .foregroundColor(.red)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.red)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.7))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}
