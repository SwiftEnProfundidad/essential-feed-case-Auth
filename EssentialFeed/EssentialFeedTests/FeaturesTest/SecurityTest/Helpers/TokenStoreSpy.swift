import EssentialFeed
import Foundation

final class TokenStoreSpy: TokenStore {
    private(set) var messages = [Message]()

    enum Message: Equatable {
        case save(Token)
        case retrieve
        case retrieveRefreshToken
        case delete
    }

    var retrieveResult: Result<Token, Error> = .failure(NSError(domain: "test", code: 0))
    var retrieveRefreshTokenResult: String = ""

    func save(_ token: Token) async throws {
        messages.append(.save(token))
    }

    func retrieve() async -> Result<Token, Error> {
        messages.append(.retrieve)
        return retrieveResult
    }

    func retrieveRefreshToken() async throws -> String {
        messages.append(.retrieveRefreshToken)
        return retrieveRefreshTokenResult
    }

    func delete() async throws {
        messages.append(.delete)
    }
}
