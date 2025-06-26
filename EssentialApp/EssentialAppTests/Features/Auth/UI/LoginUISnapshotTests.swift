import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class LoginUISnapshotTests: XCTestCase {
    func test_record_loginView_allStates() async {
        let localesToTest = localesForTesting()

        for locale in localesToTest {
            let idleVM = makeViewModel(authenticateResult: .failure(.invalidCredentials))
            let idleView = await LoginView(viewModel: idleVM)
            idleVM.errorMessage = nil
            idleVM.loginSuccess = false
            idleVM.isLoginBlocked = false
            await recordSnapshot(for: idleView, named: "LOGIN_IDLE", locale: locale)

            let successVM = makeViewModel(
                authenticateResult: .success(
                    LoginResponse(
                        user: User(name: "Test User", email: "user@example.com"),
                        token: Token(
                            accessToken: "any-token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                        )
                    )))
            let successView = await LoginView(viewModel: successVM)
            successVM.loginSuccess = true
            successVM.errorMessage = nil
            successVM.isLoginBlocked = false
            await recordSnapshot(for: successView, named: "LOGIN_SUCCESS", locale: locale)

            let errorVM = makeViewModel(authenticateResult: .failure(.invalidCredentials))
            let errorView = await LoginView(viewModel: errorVM)
            await errorVM.login()
            await recordSnapshot(for: errorView, named: "LOGIN_ERROR_INVALID_CREDENTIALS", locale: locale)

            let blockedStore = InMemoryFailedLoginAttemptsStore()

            let blockedConfiguration = LoginSecurityConfiguration(
                maxAttempts: 1, blockDuration: 300, captchaThreshold: 1
            )

            let blockedSecurityUseCase = LoginSecurityUseCase(
                store: blockedStore, configuration: blockedConfiguration
            )
            let blockedVM = LoginViewModel(
                authenticate: { _, _ in .failure(.invalidCredentials) },
                loginSecurity: blockedSecurityUseCase
            )
            let blockedView = await LoginView(viewModel: blockedVM)
            blockedVM.username = "user_to_be_locked"
            blockedVM.password = "any_password"
            await blockedVM.login()
            await recordSnapshot(for: blockedView, named: "LOGIN_BLOCKED_ACCOUNT_LOCKED", locale: locale)

            let recoveryVM = makeViewModel(authenticateResult: .failure(.invalidCredentials))
            let recoveryView = await LoginView(viewModel: recoveryVM)
            recoveryVM.errorMessage =
                "Your account is blocked. Please try again later or recover your password."
            await recordSnapshot(
                for: recoveryView, named: "LOGIN_BLOCKED_WITH_RECOVERY_SUGGESTION", locale: locale
            )
        }
    }

    func test_loginView_allStates() async {
        let localesToTest = localesForTesting()

        for locale in localesToTest {
            let idleVM = makeViewModel(authenticateResult: .failure(.invalidCredentials))
            let idleView = await LoginView(viewModel: idleVM)
            idleVM.errorMessage = nil
            idleVM.loginSuccess = false
            idleVM.isLoginBlocked = false
            assertSnapshot(for: idleView, named: "LOGIN_IDLE", locale: locale)

            let successVM = makeViewModel(
                authenticateResult: .success(
                    LoginResponse(
                        user: User(name: "Test User", email: "user@example.com"),
                        token: Token(
                            accessToken: "any-token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                        )
                    )))
            let successView = await LoginView(viewModel: successVM)
            successVM.loginSuccess = true
            successVM.errorMessage = nil
            successVM.isLoginBlocked = false
            assertSnapshot(for: successView, named: "LOGIN_SUCCESS", locale: locale)

            let errorVM = makeViewModel(authenticateResult: .failure(.invalidCredentials))
            let errorView = await LoginView(viewModel: errorVM)
            await errorVM.login()
            assertSnapshot(for: errorView, named: "LOGIN_ERROR_INVALID_CREDENTIALS", locale: locale)

            let blockedStore = InMemoryFailedLoginAttemptsStore()
            let blockedConfiguration = LoginSecurityConfiguration(
                maxAttempts: 1, blockDuration: 300, captchaThreshold: 1
            )
            let blockedSecurityUseCase = LoginSecurityUseCase(
                store: blockedStore, configuration: blockedConfiguration
            )
            let blockedVM = LoginViewModel(
                authenticate: { _, _ in .failure(.invalidCredentials) },
                loginSecurity: blockedSecurityUseCase
            )
            let blockedView = await LoginView(viewModel: blockedVM)
            blockedVM.username = "user_to_be_locked"
            blockedVM.password = "any_password"
            await blockedVM.login()
            assertSnapshot(for: blockedView, named: "LOGIN_BLOCKED_ACCOUNT_LOCKED", locale: locale)

            let recoveryVM = makeViewModel(authenticateResult: .failure(.invalidCredentials))
            let recoveryView = await LoginView(viewModel: recoveryVM)
            recoveryVM.errorMessage =
                "Your account is blocked. Please try again later or recover your password."
            assertSnapshot(
                for: recoveryView, named: "LOGIN_BLOCKED_WITH_RECOVERY_SUGGESTION", locale: locale
            )
        }
    }

    private func localesForTesting() -> [Locale] {
        return [
            Locale(identifier: "en"),
            Locale(identifier: "es"),
            Locale(identifier: "el"),
            Locale(identifier: "pt-BR")
        ]
    }

    private func makeViewModel(authenticateResult: Result<LoginResponse, LoginError>) -> LoginViewModel {
        let store = InMemoryFailedLoginAttemptsStore()
        let configuration = LoginSecurityConfiguration(
            maxAttempts: 3, blockDuration: 300, captchaThreshold: 2
        ) // Default values, adjust if needed
        let securityUseCase = LoginSecurityUseCase(store: store, configuration: configuration)
        let vm = LoginViewModel(
            authenticate: { _, _ in authenticateResult },
            loginSecurity: securityUseCase
        )
        return vm
    }

    private func recordSnapshot(
        for view: some View, named name: String, locale: Locale, file: StaticString = #filePath,
        line _: UInt = #line
    ) async {
        let styles: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]
        let snapshotsFolder = URL(fileURLWithPath: String(describing: file))
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots")

        try? FileManager.default.createDirectory(at: snapshotsFolder, withIntermediateDirectories: true)

        for (style, styleName) in styles {
            let view =
                view
                    .environment(\.locale, locale)
                    .preferredColorScheme(style == .dark ? .dark : .light)

            let viewController = await UIHostingController(rootView: view)

            let snapshot = await viewController.view!
            await MainActor.run {
                snapshot.bounds = CGRect(origin: .zero, size: UIScreen.main.bounds.size)
                if Thread.isMainThread {
                    let window = UIWindow(frame: UIScreen.main.bounds)
                    window.rootViewController = viewController
                    window.makeKeyAndVisible()
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                } else {
                    DispatchQueue.main.sync {
                        let window = UIWindow(frame: UIScreen.main.bounds)
                        window.rootViewController = viewController
                        window.makeKeyAndVisible()
                        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                    }
                }
                let renderer = UIGraphicsImageRenderer(bounds: snapshot.bounds)
                let image = renderer.image { _ in
                    snapshot.drawHierarchy(in: snapshot.bounds, afterScreenUpdates: true)
                }
                let snapshotURL = snapshotsFolder.appendingPathComponent(
                    "\(name)_\(styleName)_\(locale.identifier).png")
                if let data = image.pngData() {
                    try? data.write(to: snapshotURL)
                }
            }
        }
    }

    private func assertSnapshot(
        for view: some View, named name: String, locale: Locale, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let styles: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]

        for (style, styleSuffix) in styles {
            let configuredView =
                view
                    .environment(\.locale, locale)
                    .environment(\.colorScheme, style == .dark ? .dark : .light)

            let hostingController: UIHostingController<AnyView>
            let snapshot: UIImage

            if Thread.isMainThread {
                hostingController = UIHostingController(rootView: AnyView(configuredView))

                let window = UIWindow(frame: UIScreen.main.bounds)
                window.rootViewController = hostingController
                window.makeKeyAndVisible()

                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

                let snapshotConfiguration = SnapshotConfiguration.iPhone13(style: style)
                snapshot = hostingController.snapshot(for: snapshotConfiguration)
            } else {
                var localHostingController: UIHostingController<AnyView>!
                var localSnapshot: UIImage!

                DispatchQueue.main.sync {
                    localHostingController = UIHostingController(rootView: AnyView(configuredView))

                    let window = UIWindow(frame: UIScreen.main.bounds)
                    window.rootViewController = localHostingController
                    window.makeKeyAndVisible()

                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

                    let snapshotConfiguration = SnapshotConfiguration.iPhone13(style: style)
                    localSnapshot = localHostingController.snapshot(for: snapshotConfiguration)
                }

                hostingController = localHostingController
                snapshot = localSnapshot
            }

            let snapshotNameWithLocale =
                "\(name)_\(locale.identifier.replacingOccurrences(of: "-", with: "_"))_\(styleSuffix)"

            self.assert(snapshot: snapshot, named: snapshotNameWithLocale, file: file, line: line)
        }
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
