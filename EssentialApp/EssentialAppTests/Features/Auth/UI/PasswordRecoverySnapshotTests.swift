import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class PasswordRecoverySnapshotTests: XCTestCase {
    func test_passwordRecovery_success_light() {
        let response = PasswordRecoveryResponse(message: "Recovery email sent!")
        let sut = makeSUT(email: "user@email.com", apiResult: .success(response))
        assert(snapshot: sut.snapshot(for: .iPhone13(style: .light)), named: "PASSWORD_RECOVERY_SUCCESS_light")
    }

    func test_passwordRecovery_error_dark() {
        let sut = makeSUT(email: "user@email.com", apiResult: .failure(.emailNotFound))
        assert(snapshot: sut.snapshot(for: .iPhone13(style: .dark)), named: "PASSWORD_RECOVERY_ERROR_dark")
    }

    // MARK: - Helpers

    private func makeSUT(email: String, apiResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> UIViewController {
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
        controller.loadViewIfNeeded()
        viewModel.recoverPassword()
        return controller
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
