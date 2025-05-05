import XCTest
import EssentialFeed
import EssentialApp
import Combine

class LoginLockingIntegrationTests: XCTestCase {
	
	func test_accountLocksAfterMaxFailedAttempts_andUnlocksAfterTimeout() async {
		// Arrange
		let timeSubject = CurrentValueSubject<Date, Never>(Date())
		let store = FailedLoginAttemptsStoreSpy()
		let testUsername = "test@mail.com"
		
		let sut = makeSUT(
			store: store,
			authenticate: { _, _ in .failure(.invalidCredentials) },
			timeProvider: { timeSubject.value }
		)
		
		// Act & Assert - Fase 1: Bloqueo
		for attempt in 1...5 {
			await attemptLogin(with: sut, username: testUsername)
			XCTAssertNotNil(sut.errorMessage, "Should show error on attempt \(attempt)")
		}
		
		XCTAssertTrue(sut.isLoginBlocked, "Account should lock after 5 attempts")
		XCTAssertEqual(store.incrementAttemptsCallCount, 5, "Should record 5 attempts")
		XCTAssertEqual(store.capturedUsernames.last, testUsername, "Should capture correct user")
		
		// Act & Assert - Fase 2: Desbloqueo por timeout
		timeSubject.send(timeSubject.value.addingTimeInterval(5 * 60 + 1))
		
		// Forzar la comprobación de desbloqueo tras el timeout
		timeSubject.send(timeSubject.value.addingTimeInterval(5 * 60 + 1))
		await sut.login()
		XCTAssertFalse(sut.isLoginBlocked, "Account should unlock after timeout")
		XCTAssertEqual(sut.errorMessage, "Invalid credentials.", "Should show error after unlock since login() suma intento y pone el error")
		XCTAssertEqual(store.resetAttemptsCallCount, 1, "Should reset attempts once")
		XCTAssertEqual(store.incrementAttemptsSinceLastReset, 1, "Should record 1 attempt after reset")

		// Ahora login fallido tras el reset
		await attemptLogin(with: sut, username: testUsername)
		XCTAssertEqual(store.incrementAttemptsSinceLastReset, 2, "Should record 2 attempts after reset")
		XCTAssertEqual(store.incrementAttemptsCallCount, 7, "Should record 7 attempts en total")
		XCTAssertEqual(store.capturedUsernames.last, testUsername, "Should capture correct user")
		XCTAssertEqual(sut.errorMessage, "Invalid credentials.", "Should show error message on failed login")
	}
	
	// MARK: - Helpers
	
	private func makeSUT(
		store: FailedLoginAttemptsStore = FailedLoginAttemptsStoreSpy(),
		authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError> = { _, _ in .failure(.invalidCredentials) },
		timeProvider: @escaping () -> Date = { Date() },
		file: StaticString = #filePath,
		line: UInt = #line
	) -> LoginViewModel {
		let sut = LoginViewModel(
			authenticate: authenticate,
			pendingRequestStore: nil,
			failedAttemptsStore: store,
			maxFailedAttempts: 5,
			blockMessageProvider: DefaultLoginBlockMessageProvider(),
			timeProvider: timeProvider
		)
		trackForMemoryLeaks(sut, file: file, line: line)
		trackForMemoryLeaks(store as AnyObject, file: file, line: line)
		return sut
	}
	
	private func attemptLogin(
		with sut: LoginViewModel,
		username: String = "test@mail.com",
		password: String = "password",
		shouldFail: Bool = true
	) async {
		sut.username = username
		sut.password = password
		await sut.login()
		
		if shouldFail {
			XCTAssertNotNil(sut.errorMessage, "Should show error message on failed login")
		} else {
			XCTAssertNil(sut.errorMessage, "Shouldn't show error message on successful login")
		}
	}
}
