import Foundation
import EssentialFeed

public final class FailedLoginAttemptsStoreSpy: FailedLoginAttemptsStore {
    public private(set) var lastResetCount = 0
    public private(set) var getAttemptsCallCount = 0
    public private(set) var incrementAttemptsCallCount = 0
    public private(set) var resetAttemptsCallCount = 0
    public private(set) var capturedUsernames = [String]()
    private var attempts: [String: Int] = [:]
    private var lastAttemptTimes: [String: Date] = [:]
    
    public func getAttempts(for username: String) -> Int {
        let a = attempts[username, default: 0]
        print("🔵 [Spy] getAttempts: username=\(username), getAttemptsCallCount=\(getAttemptsCallCount+1), attempts=\(a)")
        getAttemptsCallCount += 1
        capturedUsernames.append(username)
        return attempts[username, default: 0]
    }
    
    public func incrementAttempts(for username: String) {
        print("🟡 [Spy] incrementAttempts: username=\(username), totalCalls=\(incrementAttemptsCallCount+1), attempts[\(username)]=\((attempts[username] ?? 0)+1)")
        
        incrementAttemptsCallCount += 1
        capturedUsernames.append(username)
        attempts[username, default: 0] += 1
        lastAttemptTimes[username] = Date()
    }
    
    public func resetAttempts(for username: String) {
        print("🟢 [Spy] resetAttempts: username=\(username), resetCalls=\(resetAttemptsCallCount+1), lastResetCount=\(incrementAttemptsCallCount)")
        lastResetCount = incrementAttemptsCallCount
        resetAttemptsCallCount += 1
        capturedUsernames.append(username)
        attempts[username] = 0
        lastAttemptTimes[username] = nil
    }
    
    public var incrementAttemptsSinceLastReset: Int {
        let v = incrementAttemptsCallCount - lastResetCount
        print("🟣 [Spy] incrementAttemptsSinceLastReset: \(v)")
        return incrementAttemptsCallCount - lastResetCount
    }
    public func lastAttemptTime(for username: String) -> Date? {
        return lastAttemptTimes[username]
    }
}
