
import Foundation

public final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsReader, FailedLoginAttemptsWriter, @unchecked Sendable {
    private var attempts: [String: Int] = [:]
    private var lastAttemptTimes: [String: Date] = [:]
    private let queue = DispatchQueue(label: "InMemoryFailedLoginAttemptsStore.queue", attributes: .concurrent)

    public init() {}

    public func getAttempts(for username: String) -> Int {
        queue.sync {
            attempts[username, default: 0]
        }
    }

    public func incrementAttempts(for username: String) async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.attempts[username, default: 0] += 1
                self.lastAttemptTimes[username] = Date()
                continuation.resume()
            }
        }
    }

    public func resetAttempts(for username: String) async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.attempts[username] = 0
                self.lastAttemptTimes[username] = nil
                continuation.resume()
            }
        }
    }

    public func lastAttemptTime(for username: String) -> Date? {
        queue.sync {
            lastAttemptTimes[username]
        }
    }
}
