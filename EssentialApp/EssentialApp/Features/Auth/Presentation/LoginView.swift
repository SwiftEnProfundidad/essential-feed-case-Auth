import EssentialFeed
import SwiftUI

public struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @State private var localUsername: String
    @State private var localPassword: String

    private enum Field: Hashable {
        case username
        case password
    }

    @FocusState private var focusedField: Field?

    public init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
        _localUsername = State(initialValue: viewModel.username)
        _localPassword = State(initialValue: viewModel.password)
    }

    public var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Text("MiApp")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 30)

                VStack(spacing: 20) {
                    TextField("Usuario", text: $localUsername)
                        .id(Field.username)
                        .focused($focusedField, equals: .username)
                        .onChange(of: localUsername) { newValue in
                            viewModel.username = newValue
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    SecureField("Contraseña", text: $localPassword)
                        .id(Field.password)
                        .focused($focusedField, equals: .password)
                        .onChange(of: localPassword) { newValue in
                            viewModel.password = newValue
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 40)

                Group {
                    switch viewModel.viewState {
                    case .idle:
                        VStack(spacing: 16) {
                            Text(" ")
                                .font(.caption)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .opacity(0)
                                .accessibilityHidden(true)
                            loginButton
                            forgotPasswordButton
                        }
                        .frame(maxWidth: .infinity)
                    case .blocked:
                        ProgressView()
                            .padding(.vertical)
                            .accessibilityIdentifier("login_activity_indicator")
                    case let .error(message):
                        VStack(spacing: 8) {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("login_error_message")
                            VStack(spacing: 16) {
                                loginButton
                                forgotPasswordButton
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    case let .success(message):
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding(.vertical)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("login_success_message")
                    }
                }
                .id(viewModel.viewState)
                .frame(minHeight: 80)
                .padding(.horizontal, 40)
            }
            .onChange(of: focusedField) { newFocus in
                if newFocus != nil {
                    viewModel.userWillBeginEditing()
                }
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

    private var forgotPasswordButton: some View {
        Button("¿Olvidaste tu contraseña?") {
            viewModel.handleRecoveryTap()
        }
        .foregroundColor(.blue)
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
