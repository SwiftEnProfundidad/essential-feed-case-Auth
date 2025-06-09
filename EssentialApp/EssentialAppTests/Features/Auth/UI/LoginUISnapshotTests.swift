import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class LoginUISnapshotTests: XCTestCase {
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
            let blockedConfiguration = LoginSecurityConfiguration(maxAttempts: 1, blockDuration: 300)
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
            let blockedConfiguration = LoginSecurityConfiguration(maxAttempts: 1, blockDuration: 300)
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
        }
    }

    // MARK: - Helpers

    private func makeViewModel(authenticateResult: Result<LoginResponse, LoginError>) -> LoginViewModel {
        let store = InMemoryFailedLoginAttemptsStore()
        let securityUseCase = LoginSecurityUseCase(store: store)
        let vm = LoginViewModel(
            authenticate: { _, _ in authenticateResult },
            loginSecurity: securityUseCase
        )
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
        let snapshotsFolder = URL(fileURLWithPath: String(describing: file))
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots")

        try? FileManager.default.createDirectory(at: snapshotsFolder, withIntermediateDirectories: true)

        for (style, styleSuffix) in styles {
            _ = view.environment(\.colorScheme, style == .dark ? .dark : .light)

            let hostingController: UIHostingController<Text> =
                if Thread.isMainThread {
                    UIHostingController(rootView: Text("Test"))
                } else {
                    DispatchQueue.main.sync {
                        UIHostingController(rootView: Text("Test"))
                    }
                }

            let snapshotConfiguration = SnapshotConfiguration.iPhone13(style: style)
            let snapshot = hostingController.snapshot(for: snapshotConfiguration)

            let snapshotNameWithLocale =
                "\(name)_\(locale.identifier.replacingOccurrences(of: "-", with: "_"))_\(styleSuffix)"
            let snapshotURL = snapshotsFolder.appendingPathComponent("\(snapshotNameWithLocale).png")

            if !FileManager.default.fileExists(atPath: snapshotURL.path) {
                record(snapshot: snapshot, named: snapshotNameWithLocale, file: file, line: line)
            } else {
                assert(snapshot: snapshot, named: snapshotNameWithLocale, file: file, line: line)
            }
        }
    }
}

private final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsReader, FailedLoginAttemptsWriter {
    private var attemptCounts: [String: Int] = [:]
    private var lastAttemptTimestamps: [String: Date] = [:]

    // MARK: - FailedLoginAttemptsWriter

    func incrementAttempts(for username: String) async {
        attemptCounts[username, default: 0] += 1
        lastAttemptTimestamps[username] = Date()
    }

    func resetAttempts(for username: String) async {
        attemptCounts[username] = nil
        lastAttemptTimestamps[username] = nil
    }

    // MARK: - FailedLoginAttemptsReader

    func getAttempts(for username: String) -> Int {
        attemptCounts[username] ?? 0
    }

    func lastAttemptTime(for username: String) -> Date? {
        lastAttemptTimestamps[username]
    }
}
