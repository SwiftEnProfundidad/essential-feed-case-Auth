import EssentialFeed
import Foundation

final class TokenParserSpy: TokenParser {
    func parse(from data: Data) throws -> Token {
        return Token(value: "any-access-token", expiry: Date().addingTimeInterval(3600))
    }
}
