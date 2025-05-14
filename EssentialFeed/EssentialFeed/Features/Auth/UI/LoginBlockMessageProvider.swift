import Foundation

public protocol LoginBlockMessageProvider {
    func message(forAttempts attempts: Int, maxAttempts: Int) -> String
    func message(for error: LoginError) -> String
    func message(for validation: LoginValidationError) -> String
    func messageForMaxAttemptsReached() -> String
}

public struct DefaultLoginBlockMessageProvider: LoginBlockMessageProvider {
    public init() {}
    public func message(forAttempts _: Int, maxAttempts _: Int) -> String {
        "Too many attempts. Please wait 5 minutes or reset your password."
    }

    public func message(for error: LoginError) -> String {
        switch error {
        case .invalidCredentials:
            "Invalid credentials."
        case .invalidEmailFormat:
            "Email format is invalid."
        case .invalidPasswordFormat:
            "Password cannot be empty."
        case .network:
            "Could not connect. Please try again."
        case .unknown:
            "Something went wrong. Please try again."
        case .tokenStorageFailed:
            "Token storage failed."
        case .noConnectivity:
            "No connectivity."
        case .offlineStoreFailed:
            "Offline store failed."
        }
    }

    public func message(for validation: LoginValidationError) -> String {
        switch validation {
        case .emptyEmail, .invalidEmailFormat:
            "Email format is invalid."
        case .emptyPassword, .invalidPasswordFormat:
            "Password cannot be empty."
        }
    }

    public func messageForMaxAttemptsReached() -> String {
        "Too many attempts. Please wait 5 minutes or reset your password."
    }
}
