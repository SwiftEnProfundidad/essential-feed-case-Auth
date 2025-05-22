import EssentialFeed
import SwiftUI

// MARK: - Neumorphic Style Definitions

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
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

public struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @State private var localUsername = ""
    @State private var localPassword = ""
    @FocusState private var focusedField: Field?

    @State private var titleAnimation = false
    @State private var contentAnimation = false

    enum Field: Hashable {
        case username
        case password
    }

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

            VStack {
                Spacer()
                titleView
                Spacer().frame(height: 60)
                formView
                Spacer()
                statusView
                Spacer()
            }
            .padding(.horizontal)
        }
        .onAppear {
            titleAnimation = true
            contentAnimation = true
        }
        .onChange(of: focusedField) { _ in
            viewModel.userWillBeginEditing()
        }
    }

    // MARK: - Computed UI Properties

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
        VStack(spacing: 20) {
            TextField(
                "",
                text: $localUsername,
                prompt: Text("Usuario")
                    .foregroundColor(AppTheme.Colors.textSecondary)
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
            .textFieldStyle(NeumorphicTextFieldStyle(isFocused: focusedField == .username))
            .foregroundColor(AppTheme.Colors.textPrimary)
            .accentColor(AppTheme.Colors.accentLimeGreen)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .password
            }

            SecureField(
                "",
                text: $localPassword,
                prompt: Text("Contraseña")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .font(Font.system(.callout, design: .rounded))
            )
            .id(Field.password)
            .focused($focusedField, equals: .password)
            .textFieldStyle(NeumorphicTextFieldStyle(isFocused: focusedField == .password))
            .foregroundColor(AppTheme.Colors.textPrimary)
            .accentColor(AppTheme.Colors.accentLimeGreen)
            .submitLabel(.done)
            .onSubmit {
                Task {
                    await viewModel.login()
                }
            }

            Button(action: {
                focusedField = nil
                print("[LoginView] Login button tapped.")
                Task {
                    print("[LoginView] Calling viewModel.login()...")
                    await viewModel.login()
                }
            }) {
                Text("Iniciar sesión")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(AppTheme.Colors.accentLimeGreen)
                    .font(Font.system(.headline, design: .rounded).weight(.bold))
            }
            .buttonStyle(NeumorphicButtonStyle())
            .disabled(viewModel.viewState == .blocked || viewModel.isLoginButtonDisabled)

            NavigationLink(destination: PasswordRecoveryComposer.passwordRecoveryViewScreen()) {
                Text("¿Olvidaste tu contraseña?")
                    .font(Font.system(.subheadline, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.top, 10)
        }
        .opacity(contentAnimation ? 1 : 0)
        .offset(y: contentAnimation ? 0 : 50)
        .animation(.easeInOut(duration: 0.5).delay(0.3), value: contentAnimation)
    }

    private var statusView: some View {
        Group {
            switch viewModel.viewState {
            case let .error(message):
                Text(message)
                    .foregroundColor(.red)
                    .font(Font.system(.callout, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
            case .blocked:
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.accentLimeGreen))
                    .padding()
                Text("Iniciando sesión...")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .font(Font.system(.callout, design: .rounded))
            default:
                EmptyView()
            }
        }
        .frame(height: 100)
    }
}
