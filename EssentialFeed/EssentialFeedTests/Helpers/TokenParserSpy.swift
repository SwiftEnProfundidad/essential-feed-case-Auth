import Foundation
import EssentialFeed


final class TokenParserSpy: TokenParser {
    func parse(from data: Data) throws -> Token {
        print("[TokenParserSpy] parse called with data: \(data)")
        return Token(value: "any-access-token", expiry: Date().addingTimeInterval(3600))
    }
}
