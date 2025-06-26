import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class EnhancedLoginSnapshotTests: XCTestCase {
    func testLoginViewInDifferentStates() async throws {
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]
        for language in languages {
            for (uiStyle, schemeName) in schemes {
                let locale = Locale(identifier: language)

                let idleVM = makeViewModel()
                let idleView = await LoginView(viewModel: idleVM, animationsEnabled: false).environment(\.locale, locale)
                let idleController = await MainActor.run { UIHostingController(rootView: idleView) }
                await MainActor.run {
                    idleController.overrideUserInterfaceStyle = uiStyle
                    idleController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                    idleController.loadViewIfNeeded()
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                let idleSnapshot = await MainActor.run { idleController.snapshot(for: SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale)) }
                assert(snapshot: idleSnapshot, named: "LOGIN_IDLE", language: language, scheme: schemeName)

                let validationVM = makeViewModel()
                validationVM.username = "invalid@email"
                validationVM.password = ""
                await validationVM.login()
                let validationView = await LoginView(viewModel: validationVM, animationsEnabled: false).environment(\.locale, locale)
                let validationController = await MainActor.run { UIHostingController(rootView: validationView) }
                await MainActor.run {
                    validationController.overrideUserInterfaceStyle = uiStyle
                    validationController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                    validationController.loadViewIfNeeded()
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                let validationSnapshot = await MainActor.run { validationController.snapshot(for: SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale)) }
                assert(snapshot: validationSnapshot, named: "LOGIN_FORM_VALIDATION", language: language, scheme: schemeName)

                let successVM = makeViewModel(
                    authenticateResult: .success(
                        LoginResponse(
                            user: User(name: "Test User", email: "success@email.com"),
                            token: Token(accessToken: "token123", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
                        )
                    )
                )
                successVM.username = "success@email.com"
                successVM.password = "valid_password"
                await successVM.login()
                let successView = await LoginView(viewModel: successVM, animationsEnabled: false).environment(\.locale, locale)
                let successController = await MainActor.run { UIHostingController(rootView: successView) }
                await MainActor.run {
                    successController.overrideUserInterfaceStyle = uiStyle
                    successController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                    successController.loadViewIfNeeded()
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                let successSnapshot = await MainActor.run { successController.snapshot(for: SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale)) }
                assert(snapshot: successSnapshot, named: "LOGIN_SUCCESS", language: language, scheme: schemeName)

                let errorCases: [(LoginError, String)] = [
                    (.invalidCredentials, "INVALID_CREDENTIALS"),
                    (.network, "NETWORK"),
                    (.noConnectivity, "NO_CONNECTIVITY"),
                    (.tokenStorageFailed, "TOKEN_STORAGE_FAILED"),
                    (.offlineStoreFailed, "OFFLINE_STORE_FAILED")
                ]
                for (error, stateName) in errorCases {
                    let errorVM = makeViewModel(authenticateResult: .failure(error))
                    errorVM.username = "error@email.com"
                    errorVM.password = "wrong_password"
                    await errorVM.login()
                    let errorView = await LoginView(viewModel: errorVM, animationsEnabled: false).environment(\.locale, locale)
                    let errorController = await MainActor.run { UIHostingController(rootView: errorView) }
                    await MainActor.run {
                        errorController.overrideUserInterfaceStyle = uiStyle
                        errorController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                        errorController.loadViewIfNeeded()
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    let errorSnapshot = await MainActor.run { errorController.snapshot(for: SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale)) }
                    assert(snapshot: errorSnapshot, named: "LOGIN_ERROR_\(stateName)", language: language, scheme: schemeName)
                }

                let blockedStore = InMemoryFailedLoginAttemptsStore()
                let blockedConfiguration = LoginSecurityConfiguration(maxAttempts: 1, blockDuration: 300, captchaThreshold: 1)
                let blockedSecurityUseCase = LoginSecurityUseCase(store: blockedStore, configuration: blockedConfiguration)
                let blockedVM = LoginViewModel(
                    authenticate: { _, _ in .failure(.invalidCredentials) },
                    loginSecurity: blockedSecurityUseCase
                )
                blockedVM.username = "blocked@email.com"
                blockedVM.password = "blocked_password"
                await blockedVM.login()
                let blockedView = await LoginView(viewModel: blockedVM, animationsEnabled: false).environment(\.locale, locale)
                let blockedController = await MainActor.run { UIHostingController(rootView: blockedView) }
                await MainActor.run {
                    blockedController.overrideUserInterfaceStyle = uiStyle
                    blockedController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                    blockedController.loadViewIfNeeded()
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                let blockedSnapshot = await MainActor.run { blockedController.snapshot(for: SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale)) }
                assert(snapshot: blockedSnapshot, named: "LOGIN_ACCOUNT_LOCKED", language: language, scheme: schemeName)
            }
        }
    }

    func test_loginView_withCaptchaVisible() async {
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]
        for language in languages {
            for (uiStyle, schemeName) in schemes {
                let locale = Locale(identifier: language)
                let viewModel = await MainActor.run { makeViewModel() }
                await MainActor.run {
                    viewModel.username = "test@email.com"
                    viewModel.password = "Password123!"
                    viewModel.shouldShowCaptcha = true
                }
                let loginView = await MainActor.run { LoginView(viewModel: viewModel, animationsEnabled: false).environment(\.locale, locale) }
                let hostingController = await MainActor.run { UIHostingController(rootView: loginView) }
                await MainActor.run {
                    hostingController.overrideUserInterfaceStyle = uiStyle
                    hostingController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                    hostingController.loadViewIfNeeded()
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                let snapshot = await MainActor.run {
                    hostingController.snapshot(for: SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale))
                }
                assert(snapshot: snapshot, named: "LOGIN_WITH_CAPTCHA", language: language, scheme: schemeName)
            }
        }
    }

    // MARK: - Helpers

    func makeViewModel(authenticateResult: Result<LoginResponse, LoginError> = .failure(LoginError.invalidCredentials)) -> LoginViewModel {
        let configuration = LoginSecurityConfiguration(
            maxAttempts: 3, blockDuration: 300, captchaThreshold: 2
        )
        return LoginViewModel(
            authenticate: { _, _ in authenticateResult },
            pendingRequestStore: nil,
            loginSecurity: LoginSecurityUseCase(
                store: InMemoryFailedLoginAttemptsStore(),
                configuration: configuration,
                timeProvider: { Date() }
            )
        )
    }
}
