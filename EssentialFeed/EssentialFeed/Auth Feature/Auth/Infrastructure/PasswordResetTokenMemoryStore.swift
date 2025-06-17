import Foundation

public final class PasswordResetTokenMemoryStore: PasswordResetTokenReader, PasswordResetTokenWriter, PasswordResetTokenUpdater, PasswordResetTokenCleaner {
    private var tokens: [String: PasswordResetToken] = [:]
    private let queue = DispatchQueue(label: "PasswordResetTokenMemoryStore", attributes: .concurrent)

    public init() {}

    public func getToken(_ token: String) -> PasswordResetToken? {
        queue.sync {
            tokens[token]
        }
    }

    public func getTokens(for email: String) -> [PasswordResetToken] {
        queue.sync {
            tokens.values.filter { $0.email == email }
        }
    }

    public func saveToken(_ token: PasswordResetToken) throws {
        queue.async(flags: .barrier) {
            self.tokens[token.token] = token
        }
    }

    public func markTokenAsUsed(_ token: String) throws {
        try queue.sync(flags: .barrier) {
            guard let existingToken = tokens[token] else {
                throw PasswordResetTokenError.tokenNotFound
            }
            tokens[token] = existingToken.markAsUsed()
        }
    }

    public func deleteExpiredTokens() throws {
        queue.async(flags: .barrier) {
            self.tokens = self.tokens.filter { !$0.value.isExpired }
        }
    }

    public func deleteTokens(for email: String) throws {
        queue.async(flags: .barrier) {
            self.tokens = self.tokens.filter { $0.value.email != email }
        }
    }
}
