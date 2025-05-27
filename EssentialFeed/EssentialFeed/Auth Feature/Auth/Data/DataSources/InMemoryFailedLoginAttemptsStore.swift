import Foundation

public final class InMemoryFailedLoginAttemptsStore: @unchecked Sendable, FailedLoginAttemptsStore {
    private let queue = DispatchQueue(label: "InMemoryFailedLoginAttemptsStore", attributes: .concurrent)
    private var _attempts: [String: Int] = [:]
    private var _lastAttemptTimes: [String: Date] = [:]

    public init() {}

    public func getAttempts(for username: String) -> Int {
        queue.sync {
            _attempts[username, default: 0]
        }
    }

    public func incrementAttempts(for username: String) async {
        await withCheckedContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume()
                return
            }
            self.queue.async(flags: .barrier) {
                self._attempts[username, default: 0] += 1
                self._lastAttemptTimes[username] = Date()
                continuation.resume()
            }
        }
    }

    public func resetAttempts(for username: String) async {
        await withCheckedContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume()
                return
            }
            self.queue.async(flags: .barrier) {
                self._attempts[username] = 0
                self._lastAttemptTimes[username] = nil
                continuation.resume()
            }
        }
    }

    public func lastAttemptTime(for username: String) -> Date? {
        queue.sync {
            _lastAttemptTimes[username]
        }
    }
}
