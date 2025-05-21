import EssentialFeed
import Foundation

final class TokenParserSpy: TokenParser {
    var stubbedToken: Token?
    var parseDataCallCount = 0
    var receivedData: Data?
    var shouldThrowError: Error?

    func parse(from data: Data) throws -> Token {
        parseDataCallCount += 1
        receivedData = data

        if let errorToThrow = shouldThrowError {
            throw errorToThrow
        }

        if let token = stubbedToken {
            return token
        }
        throw TokenParsingError.invalidData
    }

    func completeParse(with token: Token) {
        stubbedToken = token
        shouldThrowError = nil
    }

    func completeParse(with error: Error) {
        shouldThrowError = error
        stubbedToken = nil
    }
}
