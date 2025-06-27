import EssentialFeed
import SwiftUI
import UIKit

private let neumorphicCornerRadius: CGFloat = 15
private let neumorphicShadowRadiusNormal: CGFloat = 5
private let neumorphicShadowOffsetNormal: CGFloat = 5
private let neumorphicShadowRadiusPressedFocused: CGFloat = 3
private let neumorphicShadowOffsetPressedFocused: CGFloat = 2

struct NeumorphicTextFieldStyle: TextFieldStyle {
    var baseColor: Color
    var lightShadowColor: Color
    var darkShadowColor: Color

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: neumorphicCornerRadius)
                    .fill(baseColor)
                    .shadow(
                        color: lightShadowColor,
                        radius: neumorphicShadowRadiusNormal,
                        x: -neumorphicShadowOffsetNormal,
                        y: -neumorphicShadowOffsetNormal
                    )
                    .shadow(
                        color: darkShadowColor,
                        radius: neumorphicShadowRadiusNormal,
                        x: neumorphicShadowOffsetNormal,
                        y: neumorphicShadowOffsetNormal
                    )
            )
    }
}

struct NeumorphicButtonStyle: ButtonStyle {
    var baseColor: Color
    var lightShadowColor: Color
    var darkShadowColor: Color
    var pressedLightShadowColor: Color
    var pressedDarkShadowColor: Color
    var labelColor: Color

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(labelColor)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: neumorphicCornerRadius)
                    .fill(baseColor)
                    .shadow(
                        color: configuration.isPressed ? pressedLightShadowColor : lightShadowColor,
                        radius: configuration.isPressed
                            ? neumorphicShadowRadiusPressedFocused : neumorphicShadowRadiusNormal,
                        x: configuration.isPressed
                            ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal,
                        y: configuration.isPressed
                            ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal
                    )
                    .shadow(
                        color: configuration.isPressed ? pressedDarkShadowColor : darkShadowColor,
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
        let currentBaseColor = Color("neumorphicBaseColor")
        let currentAccentColor = Color("accentColorLimeGreen")
        let currentTextPrimaryColor = Color("primaryAppText")
        let currentTextSecondaryColor = Color("secondaryAppText")

        let lightShadow = colorScheme == .dark ? Color.white.opacity(0.25) : Color.white.opacity(0.7)
        let darkShadow = colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.2)
        let pressedLightShadow = colorScheme == .dark ? Color.white.opacity(0.2) : Color.white.opacity(0.5)
        let pressedDarkShadow = colorScheme == .dark ? Color.black.opacity(0.6) : Color.black.opacity(0.3)

        ZStack {
            currentBaseColor
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    focusedField = nil
                }

            VStack(spacing: LoginView.loginFormSpacing) {
                Text(LocalizedStringKey("LOGIN_VIEW_TITLE"))
                    .font(Font.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundColor(currentAccentColor)

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
                    .textFieldStyle(NeumorphicTextFieldStyle(
                        baseColor: currentBaseColor,
                        lightShadowColor: lightShadow,
                        darkShadowColor: darkShadow
                    ))
                    .foregroundColor(currentTextPrimaryColor)
                    .accentColor(currentAccentColor)

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
                        Task { [weak viewModel] in await viewModel?.login() }
                    }
                    .textFieldStyle(NeumorphicTextFieldStyle(
                        baseColor: currentBaseColor,
                        lightShadowColor: lightShadow,
                        darkShadowColor: darkShadow
                    ))
                    .foregroundColor(currentTextPrimaryColor)
                    .accentColor(currentAccentColor)
                }
                VStack(spacing: 16) {
                    if viewModel.shouldShowCaptcha {
                        CaptchaView(
                            token: $viewModel.captchaToken,
                            onTokenReceived: { [weak viewModel] token in
                                viewModel?.captchaToken = token
                                Task { await viewModel?.login() }
                            },
                            isVisible: true
                        )
                        .accessibilityIdentifier("captcha_view")
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let notification = viewModel.currentNotification {
                        InAppNotificationView(
                            title: notification.title,
                            message: notification.message,
                            type: notification.type,
                            actionButtonTitle: notification.actionButton ?? "OK",
                            onAction: {
                                viewModel.dismissNotification()
                            }
                        )
                        .transition(.opacity.combined(with: .scale))
                    }

                    switch viewModel.publishedViewState {
                    case .idle:
                        if viewModel.isPerformingLogin {
                            ProgressView()
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            loginButtonsView(
                                currentBaseColor: currentBaseColor,
                                lightShadow: lightShadow,
                                darkShadow: darkShadow,
                                pressedLightShadow: pressedLightShadow,
                                pressedDarkShadow: pressedDarkShadow,
                                currentAccentColor: currentAccentColor,
                                currentTextSecondaryColor: currentTextSecondaryColor
                            )
                        }

                    case .blocked:
                        blockedStateView(
                            currentBaseColor: currentBaseColor,
                            lightShadow: lightShadow,
                            darkShadow: darkShadow,
                            pressedLightShadow: pressedLightShadow,
                            pressedDarkShadow: pressedDarkShadow,
                            currentAccentColor: currentAccentColor,
                            currentTextSecondaryColor: currentTextSecondaryColor
                        )

                    case .error:
                        errorStateView(
                            currentBaseColor: currentBaseColor,
                            lightShadow: lightShadow,
                            darkShadow: darkShadow,
                            pressedLightShadow: pressedLightShadow,
                            pressedDarkShadow: pressedDarkShadow,
                            currentAccentColor: currentAccentColor,
                            currentTextSecondaryColor: currentTextSecondaryColor
                        )

                    case .success:
                        if viewModel.currentNotification == nil {
                            ProgressView()
                                .padding(.vertical, 40)
                        } else {
                            EmptyView()
                        }

                    case .showingNotification:
                        EmptyView()
                    }
                }
                .frame(minHeight: 130)
                .animation(.easeInOut(duration: 0.3), value: viewModel.shouldShowCaptcha)
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentNotification)
            }
            .padding(.horizontal, LoginView.loginPaddingHorizontal)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .opacity(contentAnimation ? 1 : 0)
            .offset(y: contentAnimation ? 0 : UIScreen.main.bounds.height / 3)
        }
        .animation(.default, value: viewModel.currentNotification)
        .onAppear {
            if animationsEnabled {
                contentAnimation = true
                titleAnimation = true
            } else {
                contentAnimation = true
                titleAnimation = true
            }
        }
        .onChange(of: focusedField) { [weak viewModel] newValue in
            if newValue != nil {
                viewModel?.userDidInitiateEditing()
            }
        }
    }

    @ViewBuilder
    private func loginButtonsView(
        currentBaseColor: Color,
        lightShadow: Color,
        darkShadow: Color,
        pressedLightShadow: Color,
        pressedDarkShadow: Color,
        currentAccentColor: Color,
        currentTextSecondaryColor: Color
    ) -> some View {
        VStack(spacing: 16) {
            Button {
                Task { [weak viewModel] in
                    focusedField = nil
                    await viewModel?.login()
                }
            } label: {
                Text(LocalizedStringKey("LOGIN_VIEW_LOGIN_BUTTON"))
                    .font(Font.system(.headline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeumorphicButtonStyle(
                baseColor: currentBaseColor,
                lightShadowColor: lightShadow,
                darkShadowColor: darkShadow,
                pressedLightShadowColor: pressedLightShadow,
                pressedDarkShadowColor: pressedDarkShadow,
                labelColor: currentAccentColor
            ))
            .disabled(viewModel.isPerformingLogin)

            VStack(alignment: .leading, spacing: 8) {
                Text("Demo Credentials:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(currentTextSecondaryColor)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Button("admin / admin") { fillCredentials("admin", "admin") }
                        Button("user / pass") { fillCredentials("user", "pass") }
                        Button("demo / demo") { fillCredentials("demo", "demo") }
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Button("test / test") { fillCredentials("test", "test") }
                        Button("offline test") { fillCredentials("offline@example.com", "any") }
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentBaseColor.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(currentTextSecondaryColor.opacity(0.2), lineWidth: 1)
                    )
            )

            Button {
                Task { [weak viewModel] in
                    focusedField = nil
                    viewModel?.handleRecoveryTap()
                }
            } label: {
                Text(LocalizedStringKey("LOGIN_VIEW_FORGOT_PASSWORD"))
                    .font(Font.system(.callout, design: .rounded).weight(.medium))
                    .foregroundColor(currentTextSecondaryColor)
            }
            .buttonStyle(SimplePressButtonStyle())
            .disabled(viewModel.isPerformingLogin)
            .padding(.top, 5)

            Button {
                Task { [weak viewModel] in
                    focusedField = nil
                    viewModel?.handleRegisterTap()
                }
            } label: {
                Text(LocalizedStringKey("LOGIN_VIEW_REGISTER_BUTTON"))
                    .font(Font.system(.callout, design: .rounded).weight(.medium))
                    .foregroundColor(currentTextSecondaryColor)
            }
            .buttonStyle(SimplePressButtonStyle())
            .disabled(viewModel.isPerformingLogin)
            .accessibilityIdentifier("register_button")
            .padding(.top, 5)
        }
    }

    private func fillCredentials(_ email: String, _ password: String) {
        viewModel.username = email
        viewModel.password = password
        focusedField = nil
    }

    @ViewBuilder
    private func blockedStateView(
        currentBaseColor: Color,
        lightShadow: Color,
        darkShadow: Color,
        pressedLightShadow: Color,
        pressedDarkShadow: Color,
        currentAccentColor: Color,
        currentTextSecondaryColor: Color
    ) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityIdentifier(
                    String(describing: LocalizedStringKey("LOGIN_ERROR_ACCOUNT_BLOCKED")))

            loginButtonsView(
                currentBaseColor: currentBaseColor,
                lightShadow: lightShadow,
                darkShadow: darkShadow,
                pressedLightShadow: pressedLightShadow,
                pressedDarkShadow: pressedDarkShadow,
                currentAccentColor: currentAccentColor,
                currentTextSecondaryColor: currentTextSecondaryColor
            )
        }
    }

    @ViewBuilder
    private func errorStateView(
        currentBaseColor: Color,
        lightShadow: Color,
        darkShadow: Color,
        pressedLightShadow: Color,
        pressedDarkShadow: Color,
        currentAccentColor: Color,
        currentTextSecondaryColor: Color
    ) -> some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 78)

            loginButtonsView(
                currentBaseColor: currentBaseColor,
                lightShadow: lightShadow,
                darkShadow: darkShadow,
                pressedLightShadow: pressedLightShadow,
                pressedDarkShadow: pressedDarkShadow,
                currentAccentColor: currentAccentColor,
                currentTextSecondaryColor: currentTextSecondaryColor
            )
        }
    }
}

struct NeumorphicButtonStyle_Previews: PreviewProvider {
    static var previews: some View {
        Button("Hello World") {}
            .buttonStyle(NeumorphicButtonStyle(baseColor: Color("neumorphicBaseColor"), lightShadowColor: Color.white.opacity(0.7), darkShadowColor: Color.black.opacity(0.2), pressedLightShadowColor: Color("neumorphicPressedLightShadow"), pressedDarkShadowColor: Color("neumorphicPressedDarkShadow"), labelColor: Color("accentColorLimeGreen")))
            .previewLayout(.sizeThatFits)
    }
}
