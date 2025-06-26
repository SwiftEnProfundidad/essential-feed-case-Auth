import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class LoginUISnapshotTests: XCTestCase {
    func test_login_idle() async {
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]
        for language in languages {
            for (uiStyle, schemeName) in schemes {
                let locale = Locale(identifier: language)
                let vm = makeViewModel(authenticateResult: .failure(.invalidCredentials))
                let view = await MainActor.run { LoginView(viewModel: vm, animationsEnabled: false).environment(
                    \.locale, locale
                ) }
                let controller = await MainActor.run { UIHostingController(rootView: view) }
                await MainActor.run {
                    controller.overrideUserInterfaceStyle = uiStyle
                    controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                    controller.loadViewIfNeeded()
                }
                let snapshot = await MainActor.run {
                    controller.snapshot(for: SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale))
                }
                assert(snapshot: snapshot, named: "LOGIN_IDLE", language: language, scheme: schemeName)
            }
        }
    }

    func test_login_error_invalidCredentials() async {
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]
        for language in languages {
            for (uiStyle, schemeName) in schemes {
                let locale = Locale(identifier: language)
                let vm = makeViewModel(authenticateResult: .failure(.invalidCredentials))
                vm.username = "error@email.com"
                vm.password = "wrong_password"
                await vm.login()
                let view = await LoginView(viewModel: vm, animationsEnabled: false)
                let controller = await MainActor.run { UIHostingController(rootView: view) }
                await MainActor.run {
                    controller.overrideUserInterfaceStyle = uiStyle
                    controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                    controller.loadViewIfNeeded()
                }
                let snapshot = await MainActor.run {
                    controller.snapshot(for: SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale))
                }
                assert(
                    snapshot: snapshot, named: "LOGIN_ERROR_INVALID_CREDENTIALS", language: language,
                    scheme: schemeName
                )
            }
        }
    }

    func makeSUT(
        authenticateResult: Result<LoginResponse, LoginError> = .failure(.invalidCredentials)
    ) -> LoginViewModel {
        let store = InMemoryFailedLoginAttemptsStore()
        let configuration = LoginSecurityConfiguration(
            maxAttempts: 3, blockDuration: 300, captchaThreshold: 2
        )
        let securityUseCase = LoginSecurityUseCase(store: store, configuration: configuration)
        let vm = LoginViewModel(
            authenticate: { _, _ in authenticateResult }, loginSecurity: securityUseCase
        )
        return vm
    }

    func makeRecoverySuggestionSUT() -> LoginViewModel {
        let store = InMemoryFailedLoginAttemptsStore()
        let configuration = LoginSecurityConfiguration(
            maxAttempts: 3, blockDuration: 300, captchaThreshold: 2
        )
        let securityUseCase = LoginSecurityUseCase(store: store, configuration: configuration)
        let vm = LoginViewModel(
            authenticate: { _, _ in .failure(.invalidCredentials) }, loginSecurity: securityUseCase
        )
        vm.errorMessage = "Your account is blocked. Please try again later or recover your password."
        return vm
    }

    func makeViewModel(authenticateResult: Result<LoginResponse, LoginError>) -> LoginViewModel {
        let store = InMemoryFailedLoginAttemptsStore()
        let configuration = LoginSecurityConfiguration(
            maxAttempts: 3, blockDuration: 300, captchaThreshold: 2
        )
        let securityUseCase = LoginSecurityUseCase(store: store, configuration: configuration)
        let vm = LoginViewModel(
            authenticate: { _, _ in authenticateResult }, loginSecurity: securityUseCase
        )
        return vm
    }
}

private final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsStore {
    private var attemptCounts: [String: Int] = [:]
    private var lastAttemptTimestamps: [String: Date] = [:]
    private let lockQueue = DispatchQueue(
        label: "com.essentialdeveloper.inmemoryfailedloginattemptsstore.lock")

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
