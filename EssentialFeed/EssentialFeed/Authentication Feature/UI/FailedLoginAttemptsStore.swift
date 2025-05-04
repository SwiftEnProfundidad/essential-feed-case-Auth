import Foundation

public protocol FailedLoginAttemptsStore {
	func getAttempts(for username: String) -> Int
	func incrementAttempts(for username: String)
	func resetAttempts(for username: String)
	func lastAttemptTime(for username: String) -> Date?
}

public final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsStore {
	private var attempts: [String: Int] = [:]
	private var lastAttemptTimes: [String: Date] = [:]
	
	public init() {}
	
	public func getAttempts(for username: String) -> Int {
		attempts[username, default: 0]
	}
	
	public func incrementAttempts(for username: String) {
		attempts[username, default: 0] += 1
		lastAttemptTimes[username] = Date()
	}
	
	public func resetAttempts(for username: String) {
		attempts[username] = 0
		lastAttemptTimes[username] = nil
	}
	
	public func lastAttemptTime(for username: String) -> Date? {
		lastAttemptTimes[username]
	}
}
