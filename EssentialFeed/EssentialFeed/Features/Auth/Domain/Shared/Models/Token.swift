
import Foundation

/// Access / refresh token con expiración.
public struct Token: Equatable {
    public let value: String
    public let expiry: Date
    
    public init(value: String, expiry: Date) {
        self.value = value
        self.expiry = expiry
    }
    
    // Equatable con tolerancia de 1 s en la fecha
    public static func == (lhs: Token, rhs: Token) -> Bool {
        let tolerance: TimeInterval = 1.0
        return lhs.value == rhs.value &&
               abs(lhs.expiry.timeIntervalSince(rhs.expiry)) < tolerance
    }
}
