import Foundation

public final class SystemTimestampProvider: TimestampProvider {
    public init() {}

    public func currentTimestamp() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
