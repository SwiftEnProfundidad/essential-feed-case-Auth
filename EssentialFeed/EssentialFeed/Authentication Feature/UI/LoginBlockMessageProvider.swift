public enum LoginValidationError {
    case emptyEmail
    case emptyPassword
}

public protocol LoginBlockMessageProvider {
    func message(forAttempts attempts: Int, maxAttempts: Int) -> String
    func message(for error: LoginError) -> String
    func message(for validation: LoginValidationError) -> String
}

public struct DefaultLoginBlockMessageProvider: LoginBlockMessageProvider {
    public init() {}
    public func message(forAttempts attempts: Int, maxAttempts: Int) -> String {
        return "Too many attempts. Please wait 5 minutes or reset your password."
    }
    public func message(for error: LoginError) -> String {
        switch error {
        case .invalidCredentials:
            return "Invalid username or password."
        case .invalidEmailFormat:
            return "Email format is invalid."
        case .invalidPasswordFormat:
            return "Password format is invalid."
        case .network:
            return "Network error. Please try again."
        case .unknown:
            return "An unknown error occurred."
        }
    }
    public func message(for validation: LoginValidationError) -> String {
        switch validation {
        case .emptyEmail:
            return "Email format is invalid."
        case .emptyPassword:
            return "Password cannot be empty."
        }
    }
}
