import Foundation

public protocol RefreshTokenUseCase {
    func execute() async throws -> Token
}
