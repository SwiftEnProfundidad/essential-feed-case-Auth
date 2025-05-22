import EssentialFeed
import SwiftUI

private let neumorphicCornerRadius: CGFloat = 15
private let neumorphicShadowRadiusNormal: CGFloat = 5
private let neumorphicShadowOffsetNormal: CGFloat = 5
private let neumorphicShadowRadiusPressedFocused: CGFloat = 3
private let neumorphicShadowOffsetPressedFocused: CGFloat = 2

private let darkThemeLightShadowColor = Color(white: 0.2, opacity: 0.6)
private let darkThemeDarkShadowColor = Color.black.opacity(0.7)

struct NeumorphicTextFieldStyle: TextFieldStyle {
    var isFocused: Bool
    let mainColor = AppTheme.Colors.neumorphicBase
    let cornerRadius: CGFloat = neumorphicCornerRadius

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(mainColor)
                    .shadow(
                        color: darkThemeLightShadowColor,
                        radius: isFocused ? neumorphicShadowRadiusPressedFocused : neumorphicShadowRadiusNormal,
                        x: isFocused ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal,
                        y: isFocused ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal
                    )
                    .shadow(
                        color: darkThemeDarkShadowColor,
                        radius: isFocused ? neumorphicShadowRadiusPressedFocused : neumorphicShadowRadiusNormal,
                        x: isFocused ? neumorphicShadowOffsetPressedFocused : neumorphicShadowOffsetNormal,
                        y: isFocused ? neumorphicShadowOffsetPressedFocused : neumorphicShadowOffsetNormal
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct NeumorphicButtonStyle: ButtonStyle {
    let mainColor = AppTheme.Colors.neumorphicBase
    let textColor = AppTheme.Colors.accentLimeGreen
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
                        color: darkThemeLightShadowColor,
                        radius: configuration.isPressed
                            ? neumorphicShadowRadiusPressedFocused : neumorphicShadowRadiusNormal,
                        x: configuration.isPressed
                            ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal,
                        y: configuration.isPressed
                            ? -neumorphicShadowOffsetPressedFocused : -neumorphicShadowOffsetNormal
                    )
                    .shadow(
                        color: darkThemeDarkShadowColor,
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
    @State private var localUsername: String
    @State private var localPassword: String

    @State private var titleAnimation: Bool = false
    @State private var contentAnimation: Bool = false

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
            AppTheme.Colors.neumorphicBase
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    focusedField = nil
                }

            VStack(spacing: 0) {
                Spacer(minLength: 20)
                titleView
                Spacer().frame(height: 40)
                formView
                Spacer().frame(height: 30)
                statusAreaView
                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .opacity(contentAnimation ? 1 : 0)
            .offset(y: contentAnimation ? 0 : 100)
            .animation(
                .interpolatingSpring(stiffness: 100, damping: 15).delay(0.2), value: contentAnimation
            )
        }
        .onAppear {
            titleAnimation = true
            contentAnimation = true
        }
        .onChange(of: focusedField) { newValue in
            if newValue != nil {
                viewModel.userDidInitiateEditing()
            }
        }
    }

    private var titleView: some View {
        Text("Mis Feeds")
            .font(Font.system(.largeTitle, design: .rounded).weight(.heavy))
            .foregroundColor(AppTheme.Colors.accentLimeGreen)
            .opacity(titleAnimation ? 1 : 0)
            .offset(y: titleAnimation ? 0 : -100)
            .animation(
                .interpolatingSpring(stiffness: 120, damping: 15).delay(0.1), value: titleAnimation
            )
    }

    private var formView: some View {
        VStack(spacing: 25) {
            TextField(
                "",
                text: $localUsername,
                prompt: Text("Usuario")
                    .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.8))
                    .font(Font.system(.callout, design: .rounded))
            )
            .id(Field.username)
            .focused($focusedField, equals: .username)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .onChange(of: localUsername) { newValue in
                viewModel.username = newValue
            }
            .onSubmit {
                focusedField = .password
            }
            .textFieldStyle(NeumorphicTextFieldStyle(isFocused: focusedField == .username))
            .foregroundColor(AppTheme.Colors.textPrimary)
            .accentColor(AppTheme.Colors.accentLimeGreen)

            SecureField(
                "", text: $localPassword,
                prompt: Text("Contraseña")
                    .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.8))
                    .font(Font.system(.callout, design: .rounded))
            )
            .id(Field.password)
            .focused($focusedField, equals: .password)
            .onChange(of: localPassword) { newValue in
                viewModel.password = newValue
            }
            .onSubmit {
                focusedField = nil
                Task { await viewModel.login() }
            }
            .textFieldStyle(NeumorphicTextFieldStyle(isFocused: focusedField == .password))
            .foregroundColor(AppTheme.Colors.textPrimary)
            .accentColor(AppTheme.Colors.accentLimeGreen)
        }
    }

    private var statusAreaView: some View {
        Group {
            switch viewModel.viewState {
            case .idle:
                VStack(spacing: 20) {
                    loginButtonNeumorphic
                    forgotPasswordButtonNeumorphic
                }
            case .blocked:
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .padding(.vertical, 40)
                    .tint(AppTheme.Colors.accentLimeGreen)
                    .accessibilityIdentifier("login_activity_indicator")
            case let .error(message):
                VStack(spacing: 15) {
                    Text(message)
                        .font(Font.system(.caption, design: .rounded).weight(.medium))
                        .foregroundColor(AppTheme.Colors.textError)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .accessibilityIdentifier("login_error_message")
                    loginButtonNeumorphic
                    forgotPasswordButtonNeumorphic
                }
            case let .success(message):
                Text(message)
                    .font(Font.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textSuccess)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 40)
                    .accessibilityIdentifier("login_success_message")
            }
        }
        .id(viewModel.viewState)
        .frame(minHeight: 130)
    }

    private var loginButtonNeumorphic: some View {
        Button {
            focusedField = nil
            Task { await viewModel.login() }
        } label: {
            Text("Iniciar sesión")
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
            Text("¿Olvidaste tu contraseña?")
                .font(Font.system(.callout, design: .rounded).weight(.medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .buttonStyle(SimplePressButtonStyle())
        .padding(.top, 5)
    }
}
