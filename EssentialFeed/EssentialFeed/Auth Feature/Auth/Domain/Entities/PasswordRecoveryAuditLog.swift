import Foundation

public struct PasswordRecoveryAuditLog: Equatable, Sendable {
    public let id: String
    public let email: String
    public let timestamp: Date
    public let ipAddress: String?
    public let userAgent: String?
    public let outcome: PasswordRecoveryOutcome
    public let errorDetails: String?

    public init(id: String = UUID().uuidString, email: String, timestamp: Date = Date(), ipAddress: String? = nil, userAgent: String? = nil, outcome: PasswordRecoveryOutcome, errorDetails: String? = nil) {
        self.id = id
        self.email = email
        self.timestamp = timestamp
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.outcome = outcome
        self.errorDetails = errorDetails
    }
}

public enum PasswordRecoveryOutcome: String, Equatable, CaseIterable, Sendable {
    case success
    case invalidEmailFormat
    case emailNotFound
    case rateLimitExceeded
    case tokenGenerationFailed
    case networkError
    case unknown
}
