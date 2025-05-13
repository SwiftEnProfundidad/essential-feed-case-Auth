import EssentialFeed
import Foundation

final class TokenParserSpy: TokenParser {
    func parse(from _: Data) throws -> Token {
        Token(value: "any-access-token", expiry: Date().addingTimeInterval(3600))
    }
}
