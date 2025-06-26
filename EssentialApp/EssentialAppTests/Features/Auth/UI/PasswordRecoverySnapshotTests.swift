import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

@MainActor
final class PasswordRecoverySnapshotTests: XCTestCase {
    func test_passwordRecovery_success_and_error_snapshots() async {
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]
        for language in languages {
            for (uiStyle, schemeName) in schemes {
                let locale = Locale(identifier: language)
                let (_, controller) = makeSUT(email: "user@email.com", apiResult: .success(PasswordRecoveryResponse(message: "Recovery email sent!")))
                controller.overrideUserInterfaceStyle = uiStyle
                controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                controller.loadViewIfNeeded()

                try? await Task.sleep(nanoseconds: 100_000_000)

                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()

                let snapshotSuccess = controller.snapshot(for: SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale))
                assert(snapshot: snapshotSuccess, named: "PASSWORD_RECOVERY_SUCCESS", language: language, scheme: schemeName)

                let (_, errorController) = makeSUT(email: "user@email.com", apiResult: .failure(.emailNotFound))
                errorController.overrideUserInterfaceStyle = uiStyle
                errorController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                errorController.loadViewIfNeeded()

                try? await Task.sleep(for: .milliseconds(100))
                try? await Task.sleep(nanoseconds: 100_000_000)

                errorController.view.setNeedsLayout()
                errorController.view.layoutIfNeeded()

                let snapshotError = errorController.snapshot(for: SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale))
                assert(snapshot: snapshotError, named: "PASSWORD_RECOVERY_ERROR", language: language, scheme: schemeName)
            }
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        email: String, apiResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>
    ) -> (PasswordRecoverySwiftUIViewModel, UIHostingController<PasswordRecoveryScreen>) {
        let api = DummyPasswordRecoveryAPI(result: apiResult)
        let rateLimiter = DummyPasswordRecoveryRateLimiter()
        let tokenManager = DummyPasswordResetTokenManager()
        let auditLogger = DummyPasswordRecoveryAuditLogger()
        let useCase = RemoteUserPasswordRecoveryUseCase(
            api: api,
            rateLimiter: rateLimiter,
            tokenManager: tokenManager,
            auditLogger: auditLogger
        )
        let viewModel = PasswordRecoverySwiftUIViewModel(recoveryUseCase: useCase)
        viewModel.email = email

        let view = PasswordRecoveryScreen(viewModel: viewModel)
        let controller = UIHostingController(rootView: view)

        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.loadViewIfNeeded()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        viewModel.recoverPassword()

        return (viewModel, controller)
    }
}

private final class DummyPasswordRecoveryAPI: PasswordRecoveryAPI {
    private let result: Result<PasswordRecoveryResponse, PasswordRecoveryError>
    init(result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        self.result = result
    }

    func recover(email _: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        completion(result)
    }
}

private final class DummyPasswordRecoveryRateLimiter: PasswordRecoveryRateLimiter {
    func isAllowed(for _: String) -> Result<Void, PasswordRecoveryError> {
        return .success(())
    }

    func recordAttempt(for _: String, ipAddress _: String?) {
        // No-op for dummy
    }
}

private final class DummyPasswordResetTokenManager: PasswordResetTokenManager {
    func generateResetToken(for email: String) throws -> PasswordResetToken {
        return PasswordResetToken(
            token: "dummy-token",
            email: email,
            expirationDate: Date().addingTimeInterval(900)
        )
    }
}

private final class DummyPasswordRecoveryAuditLogger: PasswordRecoveryAuditLogger {
    func logRecoveryAttempt(_: PasswordRecoveryAuditLog) async throws {
        // No-op for dummy
    }
}
