import Foundation

public protocol FailedLoginAttemptsStore {
	func getAttempts(for username: String) -> Int
	func incrementAttempts(for username: String)
	func resetAttempts(for username: String)
}

public final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsStore {
	private var attempts: [String: Int] = [:]
	
	public init() {}
	
	public func getAttempts(for username: String) -> Int {
		attempts[username, default: 0]
	}
	
	public func incrementAttempts(for username: String) {
		attempts[username, default: 0] += 1
	}
	
	public func resetAttempts(for username: String) {
		attempts[username] = 0
	}
}
