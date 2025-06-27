import Foundation

public struct PasswordResetToken: Equatable {
    public let token: String
    public let email: String
    public let expirationDate: Date
    public let isUsed: Bool
    public let createdAt: Date

    public init(token: String, email: String, expirationDate: Date, isUsed: Bool = false, createdAt: Date = Date()) {
        self.token = token
        self.email = email
        self.expirationDate = expirationDate
        self.isUsed = isUsed
        self.createdAt = createdAt
    }

    public var isExpired: Bool {
        Date() > expirationDate
    }

    public var isValid: Bool {
        !isUsed && !isExpired
    }

    public func markAsUsed() -> PasswordResetToken {
        PasswordResetToken(token: token, email: email, expirationDate: expirationDate, isUsed: true, createdAt: createdAt)
    }
}

public enum PasswordResetTokenError: Error, Equatable {
    case tokenNotFound
    case tokenExpired
    case tokenAlreadyUsed
    case tokenInvalid
    case storageError
    case generationFailed
    case invalidEmail
    case validationFailed(PasswordValidationError)
}
