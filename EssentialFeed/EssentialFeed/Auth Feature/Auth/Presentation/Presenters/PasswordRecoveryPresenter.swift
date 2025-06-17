import Foundation

public enum PasswordRecoveryPresenter {
    public static func map(_ result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> PasswordRecoveryViewModel {
        switch result {
        case let .success(response):
            PasswordRecoveryViewModel(message: response.message, isSuccess: true)
        case let .failure(error):
            PasswordRecoveryViewModel(message: localized(error), isSuccess: false)
        }
    }

    private static func localized(_ error: PasswordRecoveryError) -> String {
        switch error {
        case .invalidEmailFormat:
            return "Email format is not valid."
        case .emailNotFound:
            return "No account associated with that email."
        case .network:
            return "Connection error. Please try again."
        case let .rateLimitExceeded(retryAfterSeconds):
            let minutes = retryAfterSeconds / 60
            return minutes > 0
                ? "Too many attempts. Please try again in \(minutes) minutes."
                : "Too many attempts. Please try again in a few seconds."
        case .tokenGenerationFailed:
            return "Unable to generate reset token. Please try again."
        case .unknown:
            return "Unknown error. Please try again."
        }
    }
}
