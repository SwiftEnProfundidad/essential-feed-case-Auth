import Foundation

public protocol LoginErrorType: Error {
    func errorMessage() -> String
}

public enum LoginError: Error, LoginErrorType, Equatable {
    case invalidCredentials
    case invalidEmailFormat
    case invalidPasswordFormat
    case network
    case tokenStorageFailed
    case noConnectivity
    case unknown
    case offlineStoreFailed
    case accountLocked
    case messageForMaxAttemptsReached
    public func errorMessage() -> String {
        switch self {
        case .invalidCredentials:
            "Invalid credentials."
        case .invalidEmailFormat:
            "Invalid email format."
        case .invalidPasswordFormat:
            "Password cannot be empty."
        case .network:
            "Could not connect. Please try again."
        case .tokenStorageFailed:
            "Token storage failed. Please try again."
        case .noConnectivity:
            "No connectivity. Please check your internet connection."
        case .unknown:
            "Something went wrong. Please try again."
        case .offlineStoreFailed:
            "Offline store failed. Please try again."
        case .accountLocked:
            "Account temporarily locked due to multiple failed attempts. Please try again later."
        case .messageForMaxAttemptsReached:
            "Maximum number of attempts reached. Please try again later."
        }
    }
}
