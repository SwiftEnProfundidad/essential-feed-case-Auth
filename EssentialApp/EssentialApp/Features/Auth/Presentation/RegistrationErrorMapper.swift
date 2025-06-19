import EssentialFeed
import Foundation

public enum RegistrationErrorMapper {
    public static func userFriendlyMessage(for error: Error) -> String {
        if let registrationError = error as? UserRegistrationError {
            return message(for: registrationError)
        }

        if let networkError = error as? NetworkError {
            return message(for: networkError)
        }

        return error.localizedDescription
    }

    private static func message(for error: UserRegistrationError) -> String {
        switch error {
        case .emailAlreadyInUse:
            return "This email is already registered. Please use a different email or try logging in."
        case .invalidData:
            return "The registration data is invalid. Please check your information and try again."
        case .connectivity:
            return "No internet connection. Please check your network and try again."
        case .replayAttackDetected:
            return "Security validation failed. Please try again."
        case .abuseDetected:
            return "Too many registration attempts detected. Please try again later."
        case .tokenStorageFailed:
            return "Failed to save authentication data. Please try again."
        case .credentialsSaveFailed:
            return "Failed to save your credentials securely. Please try again."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }

    private static func message(for error: NetworkError) -> String {
        switch error {
        case .noConnectivity:
            return "No internet connection. Please check your network and try again."
        case .invalidResponse:
            return "Invalid server response. Please try again."
        case let .clientError(statusCode):
            return "Request error (\(statusCode)). Please check your information and try again."
        case let .serverError(statusCode):
            return "Server error (\(statusCode)). Please try again later."
        case .unknown:
            return "A network error occurred. Please try again."
        }
    }
}
