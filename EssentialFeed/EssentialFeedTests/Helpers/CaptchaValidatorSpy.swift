import EssentialFeed
import Foundation

public final class CaptchaValidatorSpy: CaptchaValidator {
    public var validateCaptchaCallCount = 0
    public var validateCaptchaArgs: [(response: String, clientIP: String?)] = []
    public var stubbedResult: CaptchaValidationResult?
    public var stubbedError: Error?

    public func validateCaptcha(response: String, clientIP: String?) async throws -> CaptchaValidationResult {
        validateCaptchaCallCount += 1
        validateCaptchaArgs.append((response, clientIP))

        if let error = stubbedError {
            throw error
        }

        return stubbedResult ?? CaptchaValidationResult(isValid: false, score: nil, challengeId: nil)
    }

    public func completeValidation(with result: CaptchaValidationResult) {
        stubbedResult = result
        stubbedError = nil
    }

    public func completeValidation(with error: Error) {
        stubbedError = error
        stubbedResult = nil
    }
}

public final class BotDetectionServiceSpy: BotDetectionService {
    public var analyzeRequestCallCount = 0
    public var analyzeRequestArgs: [(ipAddress: String?, userAgent: String?, requestPattern: RequestPattern)] = []
    public var stubbedResult: BotDetectionResult = .human

    public func analyzeRequest(ipAddress: String?, userAgent: String?, requestPattern: RequestPattern) -> BotDetectionResult {
        analyzeRequestCallCount += 1
        analyzeRequestArgs.append((ipAddress, userAgent, requestPattern))
        return stubbedResult
    }
}

public final class SecurityEventLoggerSpy: SecurityEventLogger {
    public struct LoggedEvent: Equatable {
        public let event: SecurityEvent
        public let email: String
        public let ipAddress: String?
        public let userAgent: String?
    }

    public var loggedEvents: [LoggedEvent] = []

    public func logSecurityEvent(_ event: SecurityEvent, email: String, ipAddress: String?, userAgent: String?) async {
        loggedEvents.append(LoggedEvent(event: event, email: email, ipAddress: ipAddress, userAgent: userAgent))
    }
}

public final class UserPasswordRecoveryUseCaseSpy: UserPasswordRecoveryUseCase {
    public var recoverPasswordCallCount = 0
    public var recoverPasswordArgs: [(email: String, ipAddress: String?, userAgent: String?)] = []
    public var stubbedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError> = .failure(.network)

    public func recoverPassword(email: String, ipAddress: String?, userAgent: String?, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        recoverPasswordCallCount += 1
        recoverPasswordArgs.append((email, ipAddress, userAgent))
        completion(stubbedResult)
    }
}
