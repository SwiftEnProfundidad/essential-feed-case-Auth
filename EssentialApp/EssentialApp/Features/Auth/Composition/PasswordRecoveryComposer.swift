import EssentialFeed
import SwiftUI
import UIKit

public enum PasswordRecoveryComposer {
    public static func passwordRecoveryViewScreen() -> PasswordRecoveryScreen {
        let httpClient = NetworkDependencyFactory.makeHTTPClient()
        let baseURL = ConfigurationFactory.makePasswordRecoveryBaseURL()

        let recoveryUseCase = PasswordRecoveryDependencyFactory.makeSecurePasswordRecoveryUseCase(
            httpClient: httpClient,
            baseURL: baseURL
        )

        let viewModel = PasswordRecoverySwiftUIViewModel(recoveryUseCase: recoveryUseCase)
        let recoveryView = PasswordRecoveryScreen(viewModel: viewModel)
        return recoveryView
    }

    public static func passwordRecoveryViewScreenForTesting() -> PasswordRecoveryScreen {
        let apiStub = PasswordRecoveryAPIStub(result: .success(PasswordRecoveryResponse(message: "Simulación de recuperación")))
        let rateLimiterStub = PasswordRecoveryRateLimiterStub()
        let tokenManagerStub = PasswordResetTokenManagerStub()
        let auditLoggerStub = PasswordRecoveryAuditLoggerStub()

        let recoveryUseCase = RemoteUserPasswordRecoveryUseCase(
            api: apiStub,
            rateLimiter: rateLimiterStub,
            tokenManager: tokenManagerStub,
            auditLogger: auditLoggerStub
        )

        let viewModel = PasswordRecoverySwiftUIViewModel(recoveryUseCase: recoveryUseCase)
        let recoveryView = PasswordRecoveryScreen(viewModel: viewModel)
        return recoveryView
    }
}

// MARK: - Stubs para testing

private class PasswordRecoveryAPIStub: PasswordRecoveryAPI {
    private let result: Result<PasswordRecoveryResponse, PasswordRecoveryError>
    init(result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        self.result = result
    }

    func recover(email _: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        completion(result)
    }
}

private class PasswordRecoveryRateLimiterStub: PasswordRecoveryRateLimiter {
    func isAllowed(for _: String) -> Result<Void, PasswordRecoveryError> {
        return .success(())
    }

    func recordAttempt(for _: String, ipAddress _: String?) {
        // No-op for stub
    }
}

private class PasswordResetTokenManagerStub: PasswordResetTokenManager {
    func generateResetToken(for email: String) throws -> PasswordResetToken {
        return PasswordResetToken(
            token: "stub-token-\(UUID().uuidString)",
            email: email,
            expirationDate: Date().addingTimeInterval(900)
        )
    }
}

private class PasswordRecoveryAuditLoggerStub: PasswordRecoveryAuditLogger {
    func logRecoveryAttempt(_: PasswordRecoveryAuditLog) async throws {
        // No-op for stub
    }
}
