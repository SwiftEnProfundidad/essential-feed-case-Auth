import EssentialFeed
import SwiftUI

private let neumorphicCornerRadius: CGFloat = 15
private let neumorphicShadowRadiusNormal: CGFloat = 5
private let neumorphicShadowOffsetNormal: CGFloat = 5
private let neumorphicShadowRadiusPressedFocused: CGFloat = 3
private let neumorphicShadowOffsetPressedFocused: CGFloat = 2

struct NeumorphicTextFieldStyle: TextFieldStyle {
    @Environment(\.colorScheme) var colorScheme
    var isFocused: Bool

    public init(isFocused: Bool) {
        self.isFocused = isFocused
    }

    private var mainColor: Color {
        AppTheme.Colors.neumorphicBase(for: colorScheme)
    }

    private var lightShadowColor: Color {
        colorScheme == .dark
            ? Color(white: 0.2, opacity: 0.25) // Made much more subtle for dark mode
            : Color.white.opacity(0.7)
    }

    private var darkShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.7)
            : Color(white: 0.6, opacity: 0.6)
    }

    private var cornerRadius: CGFloat = neumorphicCornerRadius

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(mainColor)
                    .shadow(
                        color: lightShadowColor,
                        radius: isFocused ? neumorphicShadowRadiusPressedFocused : neumorphicShadowRadiusNormal,
                        x: isFocused ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal,
                        y: isFocused ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal
                    )
                    .shadow(
                        color: darkShadowColor,
                        radius: isFocused ? neumorphicShadowRadiusPressedFocused : neumorphicShadowRadiusNormal,
                        x: isFocused ? neumorphicShadowOffsetPressedFocused : neumorphicShadowOffsetNormal,
                        y: isFocused ? neumorphicShadowOffsetPressedFocused : neumorphicShadowOffsetNormal
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct NeumorphicButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme

    var mainColor: Color {
        AppTheme.Colors.neumorphicBase(for: colorScheme)
    }

    var textColor: Color {
        AppTheme.Colors.accentLimeGreen(for: colorScheme)
    }

    var lightShadowColor: Color {
        colorScheme == .dark
            ? Color(white: 0.2, opacity: 0.25) // Made much more subtle for dark mode
            : Color.white.opacity(0.9)
    }

    var darkShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.7)
            : Color(white: 0.6, opacity: 0.7)
    }

    let cornerRadius: CGFloat = neumorphicCornerRadius

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(textColor)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(mainColor)
                    .shadow(
                        color: lightShadowColor,
                        radius: configuration.isPressed
                            ? neumorphicShadowRadiusPressedFocused : neumorphicShadowRadiusNormal,
                        x: configuration.isPressed
                            ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal,
                        y: configuration.isPressed
                            ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal
                    )
                    .shadow(
                        color: darkShadowColor,
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
    @Environment(\.colorScheme) var colorScheme

    @State private var titleAnimation: Bool = false
    @State private var contentAnimation: Bool = false

    private enum Field: Hashable {
        case username
        case password
    }

    @FocusState private var focusedField: Field?

    private static let loginFormSpacing: CGFloat = 25
    private static let loginPaddingHorizontal: CGFloat = 30
    private let animationsEnabled: Bool

    public init(viewModel: LoginViewModel, animationsEnabled: Bool = true) {
        self.viewModel = viewModel
        self.animationsEnabled = animationsEnabled
    }

    public var body: some View {
        ZStack {
            AppTheme.Colors.neumorphicBase(for: colorScheme)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    focusedField = nil
                }

            VStack(spacing: LoginView.loginFormSpacing) {
                titleView
                formView
                statusAreaView
            }
            .padding(.horizontal, LoginView.loginPaddingHorizontal)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .opacity(contentAnimation ? 1 : 0)
            .offset(y: contentAnimation ? 0 : UIScreen.main.bounds.height / 3)
            .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.4), value: contentAnimation)
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

    private var titleView: some View {
        Text(LocalizedStringKey("LOGIN_VIEW_TITLE"))
            .font(Font.system(.largeTitle, design: .rounded).weight(.heavy))
            .foregroundColor(AppTheme.Colors.accentLimeGreen(for: colorScheme))
            .opacity(titleAnimation ? 1 : 0)
            .offset(x: titleAnimation ? 0 : -UIScreen.main.bounds.width / 2)
            .animation(.spring(response: 1.2, dampingFraction: 0.3).delay(0.8), value: titleAnimation)
    }

    private var formView: some View {
        VStack(spacing: 25) {
            TextField(
                "",
                text: $viewModel.username,
                prompt: Text(LocalizedStringKey("LOGIN_VIEW_USERNAME_PLACEHOLDER"))
                    .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.8))
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
            .textFieldStyle(NeumorphicTextFieldStyle(isFocused: focusedField == .username))
            .foregroundColor(AppTheme.Colors.textPrimary)
            .accentColor(AppTheme.Colors.accentLimeGreen(for: colorScheme))

            SecureField(
                "",
                text: $viewModel.password,
                prompt: Text(LocalizedStringKey("LOGIN_VIEW_PASSWORD_PLACEHOLDER"))
                    .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.8))
                    .font(Font.system(.callout, design: .rounded))
            )
            .id(Field.password)
            .focused($focusedField, equals: .password)
            .onSubmit {
                focusedField = nil
                Task { await viewModel.login() }
            }
            .textFieldStyle(NeumorphicTextFieldStyle(isFocused: focusedField == .password))
            .foregroundColor(AppTheme.Colors.textPrimary)
            .accentColor(AppTheme.Colors.accentLimeGreen(for: colorScheme))
        }
    }

    private var statusAreaView: some View {
        Group {
            switch viewModel.publishedViewState {
            case .idle:
                VStack(spacing: 20) {
                    if viewModel.shouldShowCaptcha {
                        CaptchaView(
                            token: $viewModel.captchaToken,
                            onTokenReceived: { token in
                                viewModel.setCaptchaToken(token)
                            },
                            isVisible: viewModel.shouldShowCaptcha
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    loginButtonNeumorphic
                    forgotPasswordButtonNeumorphic
                    registerButtonNeumorphic
                }
            case .blocked:
                VStack(spacing: 16) {
                    ProgressView()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .accessibilityIdentifier(
                            String(describing: LocalizedStringKey("LOGIN_ERROR_ACCOUNT_BLOCKED")))
                    loginButtonNeumorphic
                    forgotPasswordButtonNeumorphic
                    registerButtonNeumorphic
                }
            case let .error(message):
                VStack(spacing: 16) {
                    Text(message)
                        .font(Font.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(AppTheme.Colors.textError)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 40)
                        .accessibilityIdentifier(String(describing: LocalizedStringKey("LOGIN_ERROR_MESSAGE_ID")))

                    if viewModel.shouldShowCaptcha {
                        CaptchaView(
                            token: $viewModel.captchaToken,
                            onTokenReceived: { token in
                                viewModel.setCaptchaToken(token)
                            },
                            isVisible: viewModel.shouldShowCaptcha
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    loginButtonNeumorphic
                    registerButtonNeumorphic
                }
            case let .success(message):
                Text(message)
                    .font(Font.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textSuccess)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 40)
                    .accessibilityIdentifier(
                        String(describing: LocalizedStringKey("LOGIN_SUCCESS_MESSAGE_ID")))
            }
        }
        .id(viewModel.publishedViewState)
        .frame(minHeight: 130)
        .animation(.easeInOut(duration: 0.3), value: viewModel.shouldShowCaptcha)
    }

    private var loginButtonNeumorphic: some View {
        Button {
            focusedField = nil
            Task { await viewModel.login() }
        } label: {
            Text(LocalizedStringKey("LOGIN_VIEW_LOGIN_BUTTON"))
                .font(Font.system(.headline, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(NeumorphicButtonStyle())
    }

    private var forgotPasswordButtonNeumorphic: some View {
        Button {
            focusedField = nil
            viewModel.handleRecoveryTap()
        } label: {
            Text(LocalizedStringKey("LOGIN_VIEW_FORGOT_PASSWORD"))
                .font(Font.system(.callout, design: .rounded).weight(.medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .buttonStyle(SimplePressButtonStyle())
        .padding(.top, 5)
    }

    private var registerButtonNeumorphic: some View {
        Button {
            focusedField = nil
            viewModel.handleRegisterTap()
        } label: {
            Text(LocalizedStringKey("LOGIN_VIEW_REGISTER_BUTTON"))
                .font(Font.system(.callout, design: .rounded).weight(.medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .buttonStyle(SimplePressButtonStyle())
        .accessibilityIdentifier("register_button")
        .padding(.top, 5)
    }
}
