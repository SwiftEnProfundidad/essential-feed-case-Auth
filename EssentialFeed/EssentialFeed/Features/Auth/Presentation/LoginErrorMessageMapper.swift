
import Foundation

public enum LoginErrorMessageMapper {
    public static func message(for error: Error) -> String {
        if let errorWithMessage = error as? LoginErrorType {
            return errorWithMessage.errorMessage()
        }
        if let loginError = error as? LoginError {
            switch loginError {
            case .invalidEmailFormat:
                return "Email format is invalid."
            case .invalidPasswordFormat:
                return "Password cannot be empty."
            case .invalidCredentials:
                return "Invalid credentials."
            case .network:
                return "Could not connect. Please try again."
            case .unknown:
                return "Something went wrong. Please try again."
            case .tokenStorageFailed:
                return "Token storage failed. Please try again."
            case .noConnectivity:
                return "No connectivity. Please check your internet connection."
            case .offlineStoreFailed:
                return "Offline store failed. Please try again."
            case .accountLocked:
                return "Account temporarily locked due to multiple failed attempts. Please try again later."
            }
        }
        return "An unknown error occurred. Please try again."
    }
}
