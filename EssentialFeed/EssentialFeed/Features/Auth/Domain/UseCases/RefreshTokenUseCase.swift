
import Foundation

public protocol RefreshTokenUseCase {
    func execute() async throws -> Token
}

public struct Token: Equatable {
    public let value: String
    public let expiry: Date
    
    public init(value: String, expiry: Date) {
        self.value = value
        self.expiry = expiry
    }
}
