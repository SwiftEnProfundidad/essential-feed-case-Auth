import Foundation

public struct Token: Equatable {
    public let value: String
    public let expiry: Date

    public init(value: String, expiry: Date) {
        self.value = value
        self.expiry = expiry
    }

    public static func == (lhs: Token, rhs: Token) -> Bool {
        let tolerance: TimeInterval = 1.0
        return lhs.value == rhs.value &&
            abs(lhs.expiry.timeIntervalSince(rhs.expiry)) < tolerance
    }
}
