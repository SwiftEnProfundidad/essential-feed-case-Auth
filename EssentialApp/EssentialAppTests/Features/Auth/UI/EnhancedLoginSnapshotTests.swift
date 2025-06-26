import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

@MainActor
final class EnhancedLoginSnapshotTests: XCTestCase {
    func test_loginViewInDifferentStates() async throws {
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]

        for language in languages {
            for (uiStyle, schemeName) in schemes {
                let locale = Locale(identifier: language)
                let config = SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale)

                let (idleVM, idleView) = makeSUT(locale: locale)
                await assertLoginSnapshotSync(for: idleView, config: config, named: "LOGIN_IDLE", language: language, scheme: schemeName)
                _ = idleVM

                let (validationVM, validationView) = makeSUT(locale: locale)
                validationVM.username = "invalidemail"
                validationVM.password = ""
                await validationVM.login()
                await assertLoginSnapshotSync(for: validationView, config: config, named: "LOGIN_FORM_VALIDATION", language: language, scheme: schemeName)
                _ = validationVM

                let successLoginResponse = LoginResponse(
                    user: User(name: "Test User", email: "success@email.com"),
                    token: Token(accessToken: "token123", expiry: Date().addingTimeInterval(3600), refreshToken: "refresh123")
                )
                let (successVM, successView) = makeSUT(authenticateResult: .success(successLoginResponse), locale: locale)
                successVM.username = "success@email.com"
                successVM.password = "valid_password"
                await successVM.login()
                await assertLoginSnapshotSync(for: successView, config: config, named: "LOGIN_SUCCESS", language: language, scheme: schemeName)
                _ = successVM

                let errorCases: [(LoginError, String)] = [
                    (.invalidCredentials, "INVALID_CREDENTIALS"),
                    (.network, "NETWORK_ERROR"),
                    (.noConnectivity, "NO_CONNECTIVITY"),
                    (.tokenStorageFailed, "TOKEN_STORAGE_FAILED"),
                    (.offlineStoreFailed, "OFFLINE_STORE_FAILED"),
                    (.accountLocked(remainingTime: 60), "ACCOUNT_LOCKED_NOTIFICATION"),
                    (.invalidEmailFormat, "INVALID_EMAIL_FORMAT_NOTIFICATION"),
                    (.invalidPasswordFormat, "INVALID_PASSWORD_FORMAT_NOTIFICATION")
                ]
                for (error, stateName) in errorCases {
                    if case .accountLocked = error, stateName == "ACCOUNT_LOCKED_NOTIFICATION" { continue }

                    let (errorVM, errorView) = makeSUT(authenticateResult: .failure(error), locale: locale)
                    errorVM.username = "error@email.com"
                    errorVM.password = "wrong_password"
                    await errorVM.login()
                    await assertLoginSnapshotSync(for: errorView, config: config, named: "LOGIN_ERROR_\(stateName)", language: language, scheme: schemeName)
                    _ = errorVM
                }

                let storeForBlockedAccount = InMemoryFailedLoginAttemptsStore()
                let blockedConfiguration = LoginSecurityConfiguration(maxAttempts: 1, blockDuration: 300, captchaThreshold: 1)
                let securityUseCaseForBlocked = LoginSecurityUseCase(store: storeForBlockedAccount, configuration: blockedConfiguration, timeProvider: { Date() })

                let (blockedVM, blockedView) = makeSUT(
                    authenticateResult: .failure(.invalidCredentials),
                    securityUseCase: securityUseCaseForBlocked,
                    locale: locale
                )
                blockedVM.username = "blocked@email.com"
                blockedVM.password = "blocked_password"
                await blockedVM.login()
                await blockedVM.login()
                await assertLoginSnapshotSync(for: blockedView, config: config, named: "LOGIN_ACCOUNT_LOCKED", language: language, scheme: schemeName)
                _ = blockedVM
            }
        }
    }

    func test_loginView_withCaptchaVisible() async throws {
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]

        for language in languages {
            for (uiStyle, schemeName) in schemes {
                let locale = Locale(identifier: language)
                let config = SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale)

                let (captchaVM, captchaView) = makeSUT(locale: locale)
                captchaVM.username = "test@email.com"
                captchaVM.password = "Password123!"
                await MainActor.run { captchaVM.shouldShowCaptcha = true }

                await assertLoginSnapshotSync(for: captchaView, config: config, named: "LOGIN_WITH_CAPTCHA", language: language, scheme: schemeName)
                _ = captchaVM
            }
        }
    }

    private func makeSUT(
        authenticateResult: Result<LoginResponse, LoginError> = .failure(LoginError.invalidCredentials),
        securityUseCase: LoginSecurityUseCase? = nil,
        locale _: Locale
    ) -> (LoginViewModel, some View) {
        let store = InMemoryFailedLoginAttemptsStore()
        let defaultConfiguration = LoginSecurityConfiguration(
            maxAttempts: 3,
            blockDuration: 300,
            captchaThreshold: 2
        )
        let finalSecurityUseCase = securityUseCase ?? LoginSecurityUseCase(
            store: store,
            configuration: defaultConfiguration,
            timeProvider: { Date() }
        )

        let vm = LoginViewModel(
            authenticate: { _, _ in authenticateResult },
            loginSecurity: finalSecurityUseCase
        )

        let view = LoginView(viewModel: vm, animationsEnabled: false)
        return (vm, view)
    }

    private func assertLoginSnapshotSync(for view: some View, config: SnapshotConfiguration, named: String, language: String, scheme: String, file: StaticString = #filePath, line: UInt = #line) async {
        let themedView = view
            .environment(\.locale, config.locale)
            .environment(\.colorScheme, config.style == .dark ? .dark : .light)

        let hostingController = UIHostingController(rootView: AnyView(themedView))
        let traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: config.style),
            UITraitCollection(displayScale: UIScreen.main.scale)
        ])
        hostingController.overrideUserInterfaceStyle = config.style
        hostingController.view.frame = CGRect(origin: .zero, size: config.size)

        await MainActor.run {
            hostingController.setOverrideTraitCollection(traitCollection, forChild: hostingController)
        }

        let window = UIWindow(frame: hostingController.view.frame)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        await MainActor.run {
            hostingController.loadViewIfNeeded()
            hostingController.view.setNeedsLayout()
            hostingController.view.layoutIfNeeded()
        }

        await Task.yield()
        try? await Task.sleep(nanoseconds: 700_000_000)

        let snapshot = await MainActor.run {
            hostingController.view.setNeedsLayout()
            hostingController.view.layoutIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            return hostingController.snapshot(for: config)
        }

        assert(snapshot: snapshot, named: named, language: language, scheme: scheme, file: file, line: line)

        await MainActor.run { window.rootViewController = nil }
    }
}

private final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsStore {
    private var attemptCounts: [String: Int] = [:]
    private var lastAttemptTimestamps: [String: Date] = [:]
    private let lockQueue = DispatchQueue(label: "com.essentialdeveloper.inmemoryfailedloginattemptsstore.lock")

    func incrementAttempts(for username: String) async {
        await Task { @MainActor in
            lockQueue.sync {
                attemptCounts[username, default: 0] += 1
                lastAttemptTimestamps[username] = Date()
            }
        }.value
    }

    func resetAttempts(for username: String) async {
        await Task { @MainActor in
            lockQueue.sync {
                attemptCounts[username] = nil
                lastAttemptTimestamps[username] = nil
            }
        }.value
    }

    func getAttempts(for username: String) -> Int {
        lockQueue.sync {
            attemptCounts[username] ?? 0
        }
    }

    func lastAttemptTime(for username: String) -> Date? {
        lockQueue.sync {
            lastAttemptTimestamps[username]
        }
    }
}
