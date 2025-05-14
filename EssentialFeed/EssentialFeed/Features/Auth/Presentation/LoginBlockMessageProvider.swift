import Foundation

public protocol LoginBlockMessageProvider {
    func message(forAttempts attempts: Int, maxAttempts: Int) -> String
    func message(for error: Error) -> String
}

public struct DefaultLoginBlockMessageProvider: LoginBlockMessageProvider {
    public init() {}

    public func message(forAttempts _: Int, maxAttempts _: Int) -> String {
        "Too many attempts. Please wait 5 minutes or reset your password."
    }

    public func message(for error: Error) -> String {
        if let errorWithMessage = error as? LoginErrorType {
            return errorWithMessage.errorMessage()
        }
        if let loginError = error as? LoginError {
            switch loginError {
            case .invalidCredentials:
                return "Invalid credentials."
            case .invalidEmailFormat:
                return "Invalid email format."
            case .invalidPasswordFormat:
                return "Password cannot be empty."
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
