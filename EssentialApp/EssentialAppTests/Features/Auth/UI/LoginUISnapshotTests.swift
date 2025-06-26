import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

@MainActor
final class LoginUISnapshotTests: XCTestCase {
    func test_login_states() async throws {
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]
        for language in languages {
            for (uiStyle, schemeName) in schemes {
                let locale = Locale(identifier: language)
                let config = SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale)

                let (idleVM, idleView) = makeSUT(authenticateResult: .failure(.invalidCredentials), locale: locale)
                await assertLoginSnapshotSync(for: idleView, config: config, named: "LOGIN_IDLE", language: language, scheme: schemeName)
                _ = idleVM

                let (errorVM, errorView) = makeSUT(authenticateResult: .failure(.invalidCredentials), locale: locale)
                errorVM.username = "any@email.com"
                errorVM.password = "any password"
                await errorVM.login()
                await assertLoginSnapshotSync(for: errorView, config: config, named: "LOGIN_ERROR_INVALID_CREDENTIALS", language: language, scheme: schemeName)
            }
        }
    }

    private func makeSUT(authenticateResult: Result<LoginResponse, LoginError>, locale _: Locale) -> (LoginViewModel, some View) {
        let store = InMemoryFailedLoginAttemptsStore()
        let configuration = LoginSecurityConfiguration(
            maxAttempts: 3, blockDuration: 300, captchaThreshold: 2
        )
        let securityUseCase = LoginSecurityUseCase(store: store, configuration: configuration)
        let vm = LoginViewModel(
            authenticate: { _, _ in authenticateResult }, loginSecurity: securityUseCase
        )
        let view = LoginView(viewModel: vm, animationsEnabled: false)
        return (vm, view)
    }

    private func assertLoginSnapshotSync(for view: some View, config: SnapshotConfiguration, named: String, language: String, scheme: String, file: StaticString = #filePath, line: UInt = #line) async {
        let themedView = view
            .environment(\.locale, config.locale)

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

        try? await Task.sleep(nanoseconds: 300_000_000)

        let snapshot = await MainActor.run { hostingController.snapshot(for: config) }
        let snapshotNameWithLocale = "\(named)_\(language)_\(config.style == .dark ? "dark" : "light")"
        assert(snapshot: snapshot, named: snapshotNameWithLocale, language: language, scheme: scheme, file: file, line: line)

        await MainActor.run { window.rootViewController = nil }
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
