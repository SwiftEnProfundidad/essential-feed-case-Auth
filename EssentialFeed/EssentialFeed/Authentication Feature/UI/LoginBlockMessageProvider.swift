import Foundation

public protocol LoginBlockMessageProvider {
    func message(forAttempts attempts: Int, maxAttempts: Int) -> String
    func message(for error: LoginError) -> String
    func message(for validation: LoginValidationError) -> String
    func messageForMaxAttemptsReached() -> String
}

public struct DefaultLoginBlockMessageProvider: LoginBlockMessageProvider {
    public init() {}
    public func message(forAttempts attempts: Int, maxAttempts: Int) -> String {
        return "Too many attempts. Please wait 5 minutes or reset your password."
    }
    public func message(for error: LoginError) -> String {
        switch error {
        case .invalidCredentials:
            return "Invalid credentials."
        case .invalidEmailFormat:
            return "Email format is invalid."
        case .invalidPasswordFormat:
            return "Password cannot be empty."
        case .network:
            return "Could not connect. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
    public func message(for validation: LoginValidationError) -> String {
        switch validation {
        case .emptyEmail, .invalidEmailFormat:
            return "Email format is invalid."
        case .emptyPassword, .invalidPasswordFormat:
            return "Password cannot be empty."
        }
    }
    public func messageForMaxAttemptsReached() -> String {
        return "Too many attempts. Please wait 5 minutes or reset your password."
    }
}
