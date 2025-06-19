import Foundation

public final class DefaultCaptchaFlowCoordinator: CaptchaFlowCoordinating {
    private let captchaValidator: CaptchaValidator
    private let failedAttemptsStore: FailedLoginAttemptsStore
    private let configuration: LoginSecurityConfiguration

    public init(
        captchaValidator: CaptchaValidator,
        failedAttemptsStore: FailedLoginAttemptsStore,
        configuration: LoginSecurityConfiguration = .default
    ) {
        self.captchaValidator = captchaValidator
        self.failedAttemptsStore = failedAttemptsStore
        self.configuration = configuration
    }

    public func shouldTriggerCaptcha(failedAttempts: Int) -> Bool {
        failedAttempts >= configuration.captchaThreshold
    }

    public func handleCaptchaValidation(token: String, username _: String) async -> Result<Void, CaptchaError> {
        do {
            let result = try await captchaValidator.validateCaptcha(response: token, clientIP: nil)
            return result.isValid ? .success(()) : .failure(.invalidResponse)
        } catch let error as CaptchaError {
            return .failure(error)
        } catch {
            return .failure(.networkError)
        }
    }
}
