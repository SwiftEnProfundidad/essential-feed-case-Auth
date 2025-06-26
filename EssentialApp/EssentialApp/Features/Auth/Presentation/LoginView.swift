import EssentialFeed
import SwiftUI
import UIKit

private let neumorphicCornerRadius: CGFloat = 15
private let neumorphicShadowRadiusNormal: CGFloat = 5
private let neumorphicShadowOffsetNormal: CGFloat = 5
private let neumorphicShadowRadiusPressedFocused: CGFloat = 3
private let neumorphicShadowOffsetPressedFocused: CGFloat = 2

struct NeumorphicTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: neumorphicCornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.white.opacity(0.7),
                        radius: neumorphicShadowRadiusNormal,
                        x: -neumorphicShadowOffsetNormal,
                        y: -neumorphicShadowOffsetNormal
                    )
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: neumorphicShadowRadiusNormal,
                        x: neumorphicShadowOffsetNormal,
                        y: neumorphicShadowOffsetNormal
                    )
            )
    }
}

struct NeumorphicButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Color("accentColorLimeGreen"))
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: neumorphicCornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.white.opacity(0.7),
                        radius: configuration.isPressed
                            ? neumorphicShadowRadiusPressedFocused : neumorphicShadowRadiusNormal,
                        x: configuration.isPressed
                            ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal,
                        y: configuration.isPressed
                            ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal
                    )
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: configuration.isPressed
                            ? neumorphicShadowRadiusPressedFocused : neumorphicShadowRadiusNormal,
                        x: configuration.isPressed
                            ? neumorphicShadowOffsetPressedFocused : neumorphicShadowOffsetNormal,
                        y: configuration.isPressed
                            ? neumorphicShadowOffsetPressedFocused : neumorphicShadowOffsetNormal
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SimplePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

public struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme

    @State private var titleAnimation = false
    @State private var contentAnimation = false
    private var animationsEnabled: Bool

    public init(viewModel: LoginViewModel, animationsEnabled: Bool = true) {
        self.viewModel = viewModel
        self.animationsEnabled = animationsEnabled
    }

    enum Field: Hashable {
        case username
        case password
    }

    private static let loginFormSpacing: CGFloat = 25
    private static let loginPaddingHorizontal: CGFloat = 30

    public var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    focusedField = nil
                }

            VStack(spacing: LoginView.loginFormSpacing) {
                Text(LocalizedStringKey("LOGIN_VIEW_TITLE"))
                    .font(Font.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundColor(AppTheme.Colors.accentLimeGreen(for: colorScheme))
                    .opacity(titleAnimation ? 1 : 0)
                    .offset(x: titleAnimation ? 0 : -UIScreen.main.bounds.width / 2)
                    .animation(.spring(response: 1.2, dampingFraction: 0.3).delay(0.8), value: titleAnimation)

                VStack(spacing: 25) {
                    TextField(
                        "",
                        text: $viewModel.username,
                        prompt: Text(LocalizedStringKey("LOGIN_VIEW_USERNAME_PLACEHOLDER"))
                            .foregroundColor(Color.secondary.opacity(0.8))
                            .font(Font.system(.callout, design: .rounded))
                    )
                    .id(Field.username)
                    .focused($focusedField, equals: .username)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        focusedField = .password
                    }
                    .textFieldStyle(NeumorphicTextFieldStyle())
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .accentColor(AppTheme.Colors.accentLimeGreen(for: colorScheme))

                    SecureField(
                        "",
                        text: $viewModel.password,
                        prompt: Text(LocalizedStringKey("LOGIN_VIEW_PASSWORD_PLACEHOLDER"))
                            .foregroundColor(Color.secondary.opacity(0.8))
                            .font(Font.system(.callout, design: .rounded))
                    )
                    .id(Field.password)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        focusedField = nil
                        Task { await viewModel.login() }
                    }
                    .textFieldStyle(NeumorphicTextFieldStyle())
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .accentColor(AppTheme.Colors.accentLimeGreen(for: colorScheme))
                }
                VStack(spacing: 16) {
                    if viewModel.shouldShowCaptcha {
                        CaptchaView(
                            token: $viewModel.captchaToken,
                            onTokenReceived: { token in
                                viewModel.setCaptchaToken(token)
                            },
                            isVisible: true
                        )
                        .accessibilityIdentifier("captcha_view")
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    switch viewModel.publishedViewState {
                    case .idle:
                        if viewModel.isPerformingLogin {
                            ProgressView()
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 16) {
                                Button {
                                    Task {
                                        focusedField = nil
                                        await viewModel.login()
                                    }
                                } label: {
                                    Text(LocalizedStringKey("LOGIN_VIEW_LOGIN_BUTTON"))
                                        .font(Font.system(.headline, design: .rounded).weight(.bold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(NeumorphicButtonStyle())
                                .disabled(viewModel.isPerformingLogin)

                                Button {
                                    Task {
                                        focusedField = nil
                                        viewModel.handleRecoveryTap()
                                    }
                                } label: {
                                    Text(LocalizedStringKey("LOGIN_VIEW_FORGOT_PASSWORD"))
                                        .font(Font.system(.callout, design: .rounded).weight(.medium))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                .buttonStyle(SimplePressButtonStyle())
                                .disabled(viewModel.isPerformingLogin)
                                .padding(.top, 5)

                                Button {
                                    Task {
                                        focusedField = nil
                                        viewModel.handleRegisterTap()
                                    }
                                } label: {
                                    Text(LocalizedStringKey("LOGIN_VIEW_REGISTER_BUTTON"))
                                        .font(Font.system(.callout, design: .rounded).weight(.medium))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                .buttonStyle(SimplePressButtonStyle())
                                .disabled(viewModel.isPerformingLogin)
                                .accessibilityIdentifier("register_button")
                                .padding(.top, 5)
                            }
                        }

                    case .blocked:
                        VStack(spacing: 16) {
                            Text(LocalizedStringKey("LOGIN_ERROR_ACCOUNT_BLOCKED"))
                                .font(Font.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundColor(Color.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .accessibilityIdentifier(
                                    String(describing: LocalizedStringKey("LOGIN_ERROR_ACCOUNT_BLOCKED")))

                            ProgressView()
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .accessibilityIdentifier(
                                    String(describing: LocalizedStringKey("LOGIN_ERROR_ACCOUNT_BLOCKED")))

                            Button {
                                Task {
                                    focusedField = nil
                                    await viewModel.login()
                                }
                            } label: {
                                Text(LocalizedStringKey("LOGIN_VIEW_LOGIN_BUTTON"))
                                    .font(Font.system(.headline, design: .rounded).weight(.bold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(NeumorphicButtonStyle())
                            .disabled(viewModel.isPerformingLogin)

                            Button {
                                Task {
                                    focusedField = nil
                                    viewModel.handleRecoveryTap()
                                }
                            } label: {
                                Text(LocalizedStringKey("LOGIN_VIEW_FORGOT_PASSWORD"))
                                    .font(Font.system(.callout, design: .rounded).weight(.medium))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .buttonStyle(SimplePressButtonStyle())
                            .disabled(viewModel.isPerformingLogin)
                            .padding(.top, 5)

                            Button {
                                Task {
                                    focusedField = nil
                                    viewModel.handleRegisterTap()
                                }
                            } label: {
                                Text(LocalizedStringKey("LOGIN_VIEW_REGISTER_BUTTON"))
                                    .font(Font.system(.callout, design: .rounded).weight(.medium))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .buttonStyle(SimplePressButtonStyle())
                            .disabled(viewModel.isPerformingLogin)
                            .accessibilityIdentifier("register_button")
                            .padding(.top, 5)
                        }

                    case let .error(message):
                        VStack(spacing: 16) {
                            Text(message)
                                .font(
                                    Font.system(viewModel.shouldShowCaptcha ? .title3 : .headline, design: .rounded)
                                        .weight(.semibold)
                                )
                                .foregroundColor(Color.red)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 40)
                                .accessibilityIdentifier(
                                    String(describing: LocalizedStringKey("LOGIN_ERROR_MESSAGE_ID")))

                            Button {
                                Task {
                                    focusedField = nil
                                    await viewModel.login()
                                }
                            } label: {
                                Text(LocalizedStringKey("LOGIN_VIEW_LOGIN_BUTTON"))
                                    .font(Font.system(.headline, design: .rounded).weight(.bold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(NeumorphicButtonStyle())
                            .disabled(viewModel.isPerformingLogin)

                            Button {
                                Task {
                                    focusedField = nil
                                    viewModel.handleRegisterTap()
                                }
                            } label: {
                                Text(LocalizedStringKey("LOGIN_VIEW_REGISTER_BUTTON"))
                                    .font(Font.system(.callout, design: .rounded).weight(.medium))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .buttonStyle(SimplePressButtonStyle())
                            .disabled(viewModel.isPerformingLogin)
                            .accessibilityIdentifier("register_button")
                            .padding(.top, 5)
                        }

                    case let .success(message):
                        VStack {
                            Text(message)
                                .font(Font.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundColor(Color.green)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 40)
                                .accessibilityIdentifier(
                                    String(describing: LocalizedStringKey("LOGIN_SUCCESS_MESSAGE_ID")))
                        }
                    }
                }
                .frame(minHeight: 130)
                .animation(.easeInOut(duration: 0.3), value: viewModel.shouldShowCaptcha)
            }
            .padding(.horizontal, LoginView.loginPaddingHorizontal)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .opacity(contentAnimation ? 1 : 0)
            .offset(y: contentAnimation ? 0 : UIScreen.main.bounds.height / 3)
            .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.4), value: contentAnimation)

            if viewModel.isPerformingLogin {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.green))
                    .scaleEffect(2)
                    .padding()
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(10)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if animationsEnabled {
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 15).delay(0.2)) {
                    contentAnimation = true
                }
                titleAnimation = true
            } else {
                contentAnimation = true
                titleAnimation = true
            }
        }
        .onChange(of: focusedField) { newValue in
            if newValue != nil {
                viewModel.userDidInitiateEditing()
            }
        }
    }
}

struct NeumorphicButtonStyle_Previews: PreviewProvider {
    static var previews: some View {
        Button("Hello World") {}
            .buttonStyle(NeumorphicButtonStyle())
            .previewLayout(.sizeThatFits)
    }
}
