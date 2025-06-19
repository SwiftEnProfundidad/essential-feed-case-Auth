import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class LoginUISnapshotTests: XCTestCase {
    // NOTE: test_record_loginView_allStates is marked private as it seems to be a helper for recording, not a runnable test.
    // If it's meant to be a runnable test, remove `private`.
    private func test_record_loginView_allStates() async {
        let localesToTest = [
            Locale(identifier: "en"),
            Locale(identifier: "es"),
            Locale(identifier: "el"),
            Locale(identifier: "pt-BR")
        ]

        for locale in localesToTest {
            let idleVM = makeViewModel(authenticateResult: .failure(.invalidCredentials))
            let idleView = await LoginView(viewModel: idleVM)
            idleVM.errorMessage = nil
            idleVM.loginSuccess = false
            idleVM.isLoginBlocked = false
            await recordSnapshot(for: idleView, named: "LOGIN_IDLE", locale: locale)

            let successVM = makeViewModel(authenticateResult: .success(LoginResponse(token: "any-token")))
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
            // THE FIX IS FOR THIS LINE:
            let blockedConfiguration = LoginSecurityConfiguration(maxAttempts: 1, blockDuration: 300, captchaThreshold: 1)

            let blockedSecurityUseCase = LoginSecurityUseCase(store: blockedStore, configuration: blockedConfiguration)
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
            recoveryVM.errorMessage = "Your account is blocked. Please try again later or recover your password."
            await recordSnapshot(for: recoveryView, named: "LOGIN_BLOCKED_WITH_RECOVERY_SUGGESTION", locale: locale)
        }
    }

    func test_loginView_allStates() async {
        let localesToTest = [
            Locale(identifier: "en"),
            Locale(identifier: "es"),
            Locale(identifier: "el"),
            Locale(identifier: "pt-BR")
        ]

        for locale in localesToTest {
            let idleVM = makeViewModel(authenticateResult: .failure(.invalidCredentials))
            let idleView = await LoginView(viewModel: idleVM)
            idleVM.errorMessage = nil
            idleVM.loginSuccess = false
            idleVM.isLoginBlocked = false
            assertSnapshot(for: idleView, named: "LOGIN_IDLE", locale: locale)

            let successVM = makeViewModel(authenticateResult: .success(LoginResponse(token: "any-token")))
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
            // CORRECTED LINE: (This one was already correct in your paste, but ensuring it stays correct)
            let blockedConfiguration = LoginSecurityConfiguration(maxAttempts: 1, blockDuration: 300, captchaThreshold: 1)
            let blockedSecurityUseCase = LoginSecurityUseCase(store: blockedStore, configuration: blockedConfiguration)
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
            recoveryVM.errorMessage = "Your account is blocked. Please try again later or recover your password."
            assertSnapshot(for: recoveryView, named: "LOGIN_BLOCKED_WITH_RECOVERY_SUGGESTION", locale: locale)
        }
    }

    // MARK: - Helpers

    private func makeViewModel(authenticateResult: Result<LoginResponse, LoginError>) -> LoginViewModel {
        let store = InMemoryFailedLoginAttemptsStore()
        // CORRECTED: Ensure LoginSecurityUseCase is initialized with a configuration that includes captchaThreshold
        let configuration = LoginSecurityConfiguration(maxAttempts: 3, blockDuration: 300, captchaThreshold: 2) // Default values, adjust if needed
        let securityUseCase = LoginSecurityUseCase(store: store, configuration: configuration)
        let vm = LoginViewModel(
            authenticate: { _, _ in authenticateResult },
            loginSecurity: securityUseCase
        )
        // Consider adding trackForMemoryLeaks here for vm and securityUseCase if not done elsewhere
        return vm
    }

    private func recordSnapshot(for view: some View, named name: String, locale: Locale, file: StaticString = #filePath, line _: UInt = #line) async {
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
            }
            let renderer = await UIGraphicsImageRenderer(bounds: snapshot.bounds)
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

    private func assertSnapshot(for view: some View, named name: String, locale: Locale, file: StaticString = #filePath, line: UInt = #line) {
        let styles: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]

        for (style, styleSuffix) in styles {
            let configuredView = view
                .environment(\.locale, locale)
                .environment(\.colorScheme, style == .dark ? .dark : .light)

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

private final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsStore { // Conforms to FailedLoginAttemptsStore
    private var attemptCounts: [String: Int] = [:]
    private var lastAttemptTimestamps: [String: Date] = [:]
    private let lockQueue = DispatchQueue(label: "com.essentialdeveloper.inmemoryfailedloginattemptsstore.lock")

    func incrementAttempts(for username: String) async {
        await Task { @MainActor in // Ensure modifications are thread-safe if called from multiple threads
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
