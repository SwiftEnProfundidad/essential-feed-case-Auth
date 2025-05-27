import Foundation

public protocol BackoffPolicyProtocol {
    func backoffDuration(for failedAttempts: Int) -> TimeInterval
}

public struct ExponentialBackoffPolicy: BackoffPolicyProtocol, Equatable, Codable {
    public let baseDelay: TimeInterval
    public let factor: Double
    public let maxDelay: TimeInterval

    public init(baseDelay: TimeInterval = 2, factor: Double = 2.0, maxDelay: TimeInterval = 300) {
        self.baseDelay = baseDelay
        self.factor = factor
        self.maxDelay = maxDelay
    }

    public func backoffDuration(for failedAttempts: Int) -> TimeInterval {
        guard failedAttempts > 0 else { return 0 }
        let delay = baseDelay * pow(factor, Double(failedAttempts - 1))
        return delay > maxDelay ? maxDelay : delay
    }
}
