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

                // MARK: - Idle State

                var idleVM: LoginViewModel?
                var idleSUT: UIViewController?
                weak var weakIdleVM: LoginViewModel?
                weak var weakIdleSUT: UIViewController?

                (idleVM, idleSUT) = makeSUT(authenticateResult: .failure(.invalidCredentials), locale: locale)
                weakIdleVM = idleVM
                weakIdleSUT = idleSUT

                await assertSnapshot(for: idleSUT!, config: config, named: "LOGIN_IDLE", language: language, scheme: schemeName)

                idleVM = nil
                idleSUT = nil

                try await Task.sleep(nanoseconds: 300_000_000)

                XCTAssertNil(weakIdleVM, "Idle ViewModel should have been deallocated. Potential memory leak.", file: #filePath, line: #line)
                XCTAssertNil(weakIdleSUT, "Idle SUT should have been deallocated. Potential memory leak.", file: #filePath, line: #line)

                // MARK: - Error State

                var errorVM: LoginViewModel?
                var errorSUT: UIViewController?
                weak var weakErrorVM: LoginViewModel?
                weak var weakErrorSUT: UIViewController?

                (errorVM, errorSUT) = makeSUT(authenticateResult: .failure(.invalidCredentials), locale: locale)
                weakErrorVM = errorVM
                weakErrorSUT = errorSUT

                errorVM?.username = "any@email.com"
                errorVM?.password = "any password"
                await errorVM?.login()

                await assertSnapshot(
                    for: errorSUT!, config: config, named: "LOGIN_ERROR_INVALID_CREDENTIALS",
                    language: language, scheme: schemeName
                )

                errorVM = nil
                errorSUT = nil
                try await Task.sleep(nanoseconds: 300_000_000)
                XCTAssertNil(weakErrorVM, "Error ViewModel should have been deallocated. Potential memory leak.", file: #filePath, line: #line)
                XCTAssertNil(weakErrorSUT, "Error SUT should have been deallocated. Potential memory leak.", file: #filePath, line: #line)
            }
        }
    }

    private func makeSUT(authenticateResult: Result<LoginResponse, LoginError>, locale: Locale) -> (LoginViewModel, UIViewController) {
        let store = InMemoryFailedLoginAttemptsStore()
        let configuration = LoginSecurityConfiguration(
            maxAttempts: 3, blockDuration: 300, captchaThreshold: 2
        )
        let securityUseCase = LoginSecurityUseCase(store: store, configuration: configuration)
        let vm = LoginViewModel(
            authenticate: { _, _ in authenticateResult }, loginSecurity: securityUseCase
        )

        let view = LoginView(viewModel: vm, animationsEnabled: false).environment(\.locale, locale)
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .clear
        return (vm, controller)
    }

    private func assertSnapshot(
        for controller: UIViewController, config: SnapshotConfiguration, named: String,
        language: String, scheme: String, file: StaticString = #filePath, line: UInt = #line
    ) async {
        let window = UIWindow(frame: CGRect(origin: .zero, size: config.size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        try? await Task.sleep(nanoseconds: 200_000_000)
        let snapshot = controller.snapshot(for: config)
        assert(snapshot: snapshot, named: named, language: language, scheme: scheme, file: file, line: line)
        window.rootViewController = nil
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
