import Foundation

public struct FailedLoginAttempt: Equatable, Codable {
    public let username: String
    public let timestamp: Date
    public let reason: Reason

    public enum Reason: String, Codable, Equatable {
        case invalidCredentials
        case networkError
        case unknownError
        // Puedes añadir más razones según la lógica de negocio
    }

    public init(username: String, timestamp: Date = Date(), reason: Reason) {
        self.username = username
        self.timestamp = timestamp
        self.reason = reason
    }
}
