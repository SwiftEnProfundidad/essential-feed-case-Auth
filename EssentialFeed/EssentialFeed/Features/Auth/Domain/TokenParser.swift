
import Foundation

// El Token parseado aquí será el struct Token { value: String, expiry: Date }
// definido en EssentialFeed.RefreshTokenUseCase
public protocol TokenParser {
    func parse(from data: Data) throws -> Token 
}

