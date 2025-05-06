import Foundation
import EssentialFeed

final class TokenStorageSpy: TokenStorage {
    enum Message { case loadRefreshToken, save }
    private(set) var messages = [Message]()
    
    func loadRefreshToken() throws -> String {
        print("[TokenStorageSpy] loadRefreshToken called")
        messages.append(.loadRefreshToken)
        return "any-token"
    }
    
    func save(token: Token) throws {
        print("[TokenStorageSpy] save called with token: \(token)")
        messages.append(.save)
    }
}
