import Foundation

public struct Attempt: Equatable {
    public let timestamp: Date

    public init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
