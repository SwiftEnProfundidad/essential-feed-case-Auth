import Foundation

public struct PasswordRecoveryRequest {
    public let email: String
    public init(email: String) {
        self.email = email
    }
}

public struct PasswordRecoveryResponse: Equatable {
    public let message: String
    public init(message: String) {
        self.message = message
    }
}

public enum PasswordRecoveryError: Error, Equatable {
    case invalidEmailFormat
    case emailNotFound
    case network
    case rateLimitExceeded(retryAfterSeconds: Int)
    case unknown
}

public protocol PasswordRecoveryAPI {
    func recover(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void)
}

public struct PasswordRecoveryAttempt: Equatable {
    public let email: String
    public let timestamp: Date
    public let ipAddress: String?

    public init(email: String, timestamp: Date, ipAddress: String? = nil) {
        self.email = email
        self.timestamp = timestamp
        self.ipAddress = ipAddress
    }
}
