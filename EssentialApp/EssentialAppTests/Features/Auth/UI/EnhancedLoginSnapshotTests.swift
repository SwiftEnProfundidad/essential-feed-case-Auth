import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class EnhancedLoginSnapshotTests: XCTestCase {
    func testLoginViewInDifferentStates() async throws {
        let locales: [Locale] = [
            Locale(identifier: "en"),
            Locale(identifier: "es")
        ]

        for locale in locales {
            let idleVM = makeViewModel()
            let idleView = await LoginView(viewModel: idleVM, animationsEnabled: false)
            assertSnapshot(for: idleView, named: "LOGIN_IDLE", locale: locale)

            let validationVM = makeViewModel()
            validationVM.username = "invalid@email"
            validationVM.password = ""
            await validationVM.login()
            let validationView = await LoginView(viewModel: validationVM, animationsEnabled: false)
            assertSnapshot(for: validationView, named: "LOGIN_FORM_VALIDATION", locale: locale)

            let successVM = makeViewModel(authenticateResult: .success(LoginResponse(
                user: User(name: "Test User", email: "success@email.com"),
                token: Token(accessToken: "token123", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
            )))
            successVM.username = "success@email.com"
            successVM.password = "valid_password"
            await successVM.login()
            let successView = await LoginView(viewModel: successVM, animationsEnabled: false)
            assertSnapshot(for: successView, named: "LOGIN_SUCCESS", locale: locale)

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
                let errorView = await LoginView(viewModel: errorVM, animationsEnabled: false)
                assertSnapshot(for: errorView, named: "LOGIN_ERROR_\(stateName)", locale: locale)
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

            let blockedView = await LoginView(viewModel: blockedVM, animationsEnabled: false)
            assertSnapshot(for: blockedView, named: "LOGIN_ACCOUNT_LOCKED", locale: locale)
        }
    }

    // MARK: - Helpers

    private func makeViewModel(
        authenticateResult: Result<LoginResponse, LoginError> = .failure(LoginError.invalidCredentials)
    ) -> LoginViewModel {
        let configuration = LoginSecurityConfiguration(maxAttempts: 3, blockDuration: 300, captchaThreshold: 2)
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

    private func assertSnapshot(for view: some View, named name: String, locale: Locale, file: StaticString = #filePath, line: UInt = #line) {
        let styles: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]

        for (style, styleSuffix) in styles {
            let configuredView = view
                .environment(\.locale, locale)
                .preferredColorScheme(style == .dark ? .dark : .light)

            let hostingController: UIHostingController<AnyView> =
                if Thread.isMainThread {
                    UIHostingController(rootView: AnyView(configuredView))
                } else {
                    DispatchQueue.main.sync {
                        UIHostingController(rootView: AnyView(configuredView))
                    }
                }

            let snapshotConfiguration = SnapshotConfiguration.iPhone13(style: style)
            let snapshot = hostingController.snapshot(for: snapshotConfiguration)

            let snapshotNameWithLocale =
                "\(name)_\(locale.identifier.replacingOccurrences(of: "-", with: "_"))_\(styleSuffix)"

            self.assert(snapshot: snapshot, named: snapshotNameWithLocale, file: file, line: line)
        }
    }
}
