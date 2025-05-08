import EssentialFeed
import XCTest

final class UserLoginUseCaseTests: XCTestCase {
	
	func test_login_fails_withEmptyEmail_andDoesNotSendRequest() async {
		let (sut, api, _, failureObserver, _, _) = makeSUT()
		let credentials = LoginCredentials(email: "", password: "ValidPassword123")
		let result = await sut.login(with: credentials)
		switch result {
			case .failure(let error):
				XCTAssertEqual(error, .invalidEmailFormat, "Should return invalid email format error for empty email")
				XCTAssertFalse(api.wasCalled, "API should NOT be called when email is empty")
				XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
			case .success:
				XCTFail("Expected failure, got success")
		}
	}
	
	func test_login_fails_withWhitespaceOnlyEmail_andDoesNotSendRequest() async {
		let (sut, api, _, failureObserver, _, _) = makeSUT()
		let credentials = LoginCredentials(email: "    ", password: "ValidPassword123")
		let result = await sut.login(with: credentials)
		switch result {
			case .failure(let error):
				XCTAssertEqual(error, .invalidEmailFormat, "Should return invalid email format error for whitespace-only email")
				XCTAssertFalse(api.wasCalled, "API should NOT be called when email is whitespace-only")
				XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
			case .success:
				XCTFail("Expected failure, got success")
		}
	}
	
	func test_login_fails_withWhitespaceOnlyPassword_andDoesNotSendRequest() async {
		let (sut, api, _, failureObserver, _, _) = makeSUT()
		let credentials = LoginCredentials(email: "user@example.com", password: "     ")
		let result = await sut.login(with: credentials)
		switch result {
			case .failure(let error):
				XCTAssertEqual(error, .invalidPasswordFormat, "Should return invalid password format error for whitespace-only password")
				XCTAssertFalse(api.wasCalled, "API should NOT be called when password is whitespace-only")
				XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
			case .success:
				XCTFail("Expected failure, got success")
		}
	}
	
	func test_login_fails_withShortPassword_andDoesNotSendRequest() async {
		let (sut, api, _, failureObserver, _, _) = makeSUT()
		let credentials = LoginCredentials(email: "user@example.com", password: "12345")
		let result = await sut.login(with: credentials)
		switch result {
			case .failure(let error):
				XCTAssertEqual(error, .invalidPasswordFormat, "Should return invalid password format error for short password")
				XCTAssertFalse(api.wasCalled, "API should NOT be called when password is too short")
				XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
			case .success:
				XCTFail("Expected failure, got success")
		}
	}
	
	func test_login_fails_withEmptyEmailAndPassword_andDoesNotSendRequest() async {
		let (sut, api, _, failureObserver, _, _) = makeSUT()
		let credentials = LoginCredentials(email: "", password: "")
		let result = await sut.login(with: credentials)
		switch result {
			case .failure(let error):
				XCTAssertEqual(error, .invalidEmailFormat, "Should return invalid email format error when both fields are empty (email checked first)")
				XCTAssertFalse(api.wasCalled, "API should NOT be called when both fields are empty")
				XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
			case .success:
				XCTFail("Expected failure, got success")
		}
	}
	
	func test_login_fails_withInvalidEmailFormat_andDoesNotSendRequest() async {
		let (sut, api, _, failureObserver, _, _) = makeSUT()
		let invalidEmail = "usuario_invalido"
		let credentials = LoginCredentials(email: invalidEmail, password: "ValidPassword123")
		
		let result = await sut.login(with: credentials)
		
		switch result {
			case .failure(let error):
				XCTAssertEqual(error, .invalidEmailFormat, "Should return invalid email format error")
				XCTAssertFalse(api.wasCalled, "API should NOT be called when email format is invalid")
				XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
			case .success:
				XCTFail("Expected failure, got success")
		}
	}
	
	func test_login_fails_withInvalidPassword_andDoesNotSendRequest() async {
		let (sut, api, _, failureObserver, _, _) = makeSUT()
		let invalidPassword = ""
		let credentials = LoginCredentials(email: "user@example.com", password: invalidPassword)
		
		let result = await sut.login(with: credentials)
		
		switch result {
			case .failure(let error):
				XCTAssertEqual(error, .invalidPasswordFormat, "Should return invalid password format error")
				XCTAssertFalse(api.wasCalled, "API should NOT be called when password is invalid")
				XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on validation error")
			case .success:
				XCTFail("Expected failure, got success")
		}
	}
	
	func test_login_fails_onInvalidCredentials() async throws {
		let (sut, api, _, failureObserver, _, _) = makeSUT()
		let credentials = LoginCredentials(email: "user@example.com", password: "wrongpass")
		
		api.stubbedResult = Result<LoginResponse, LoginError>.failure(.invalidCredentials)
		
		let result = await sut.login(with: credentials)
		switch result {
			case .success:
				XCTFail("Expected failure, got success")
			case let .failure(error):
				XCTAssertEqual(error, .invalidCredentials, "Should return invalid credentials error on failure")
				XCTAssertTrue(failureObserver.didNotifyFailure, "Failure observer should be notified on failed login")
		}
	}
	
	func test_login_succeeds_storesToken_andNotifiesObserver() async throws {
		let (sut, api, successObserver, _, tokenStorage, _) = makeSUT()
		let credentials = LoginCredentials(email: "user@example.com", password: "password123")
		
		let expectedTokenValue = "jwt-token-123"
		let expectedTokenExpiry = Date().addingTimeInterval(3600)
		let expectedToken = Token(value: expectedTokenValue, expiry: expectedTokenExpiry)
		let apiResponse = LoginResponse(token: expectedTokenValue)
		
		api.stubbedResult = .success(apiResponse)
		
		let result = await sut.login(with: credentials)
		switch result {
			case let .success(response):
				XCTAssertEqual(response.token, expectedTokenValue, "Returned token value should match expected token value")
				XCTAssertTrue(successObserver.didNotifySuccess, "Success observer should be notified on successful login")
				XCTAssertEqual(tokenStorage.messages.count, 1, "Expected 1 message (save) in TokenStorageSpy")
				guard tokenStorage.messages.count == 1 else { return }
				switch tokenStorage.messages[0] {
					case .save(let savedToken):
						XCTAssertEqual(savedToken.value, expectedToken.value, "Saved token value mismatch")
						XCTAssertTrue(abs(savedToken.expiry.timeIntervalSince(expectedToken.expiry)) < 1.0, "Saved token expiry mismatch")
					default:
						XCTFail("Expected .save message, got \(tokenStorage.messages[0])")
				}
				
			case .failure(let error):
				XCTFail("Expected success, got failure: \(error)")
		}
	}
	
	func test_login_succeedsApiCall_butFailsToStoreToken_returnsError() async throws {
		let (sut, api, successObserver, _, tokenStorage, _) = makeSUT()
		let credentials = LoginCredentials(email: "user@example.com", password: "password123")
		
		let expectedTokenValue = "jwt-token-for-fail-case"
		let apiResponse = LoginResponse(token: expectedTokenValue)
		api.stubbedResult = .success(apiResponse)
		
		let storageError = NSError(domain: "TokenStorageError", code: 1) // Este es el error que el Spy simula
		tokenStorage.saveTokenError = storageError
		
		let result = await sut.login(with: credentials)
		
		switch result {
			case .success:
				XCTFail("Expected failure due to token storage error, got success")
			case .failure(let error): // 'error' aquí es de tipo LoginError
				
				XCTAssertEqual(error, LoginError.tokenStorageFailed, "Expected token storage error")
		}
		XCTAssertFalse(successObserver.didNotifySuccess, "Success observer should NOT be notified if token storage fails")
		XCTAssertEqual(tokenStorage.messages.count, 1, "Expected TokenStorage save attempt")
	}
	
	private func makeSUT(
		file: StaticString = #file, line: UInt = #line
	) -> (
		sut: UserLoginUseCase,
		api: AuthAPISpy,
		successObserver: LoginSuccessObserverSpy,
		failureObserver: LoginFailureObserverSpy,
		tokenStorage: TokenStorageSpy,
		offlineStore: OfflineLoginStoreSpy
	) {
		let api = AuthAPISpy()
		let successObserver = LoginSuccessObserverSpy()
		let failureObserver = LoginFailureObserverSpy()
		let tokenStorage = TokenStorageSpy()
		let offlineStore = OfflineLoginStoreSpy()
		
		let sut = UserLoginUseCase(
			api: api,
			tokenStorage: tokenStorage,
			offlineStore: offlineStore,
			successObserver: successObserver,
			failureObserver: failureObserver
		)
		
		trackForMemoryLeaks(api, file: file, line: line)
		trackForMemoryLeaks(successObserver, file: file, line: line)
		trackForMemoryLeaks(failureObserver, file: file, line: line)
		trackForMemoryLeaks(tokenStorage, file: file, line: line)
		trackForMemoryLeaks(offlineStore, file: file, line: line)
		trackForMemoryLeaks(sut, file: file, line: line)
		
		return (sut, api, successObserver, failureObserver, tokenStorage, offlineStore)
	}
}

// MARK: - Helpers & Spies

public final class OfflineLoginStoreSpy: OfflineLoginStore {
	enum Message: Equatable {
		case save(LoginCredentials)
	}
	private(set) var messages = [Message]()
	var saveError: Error?
	
	public func save(credentials: LoginCredentials) async throws {
		if let error = saveError {
			throw error
		}
		messages.append(.save(credentials))
	}
}

final class LoginSuccessObserverSpy: LoginSuccessObserver {
	var didNotifySuccess = false
	func didLoginSuccessfully(response: LoginResponse) {
		didNotifySuccess = true
	}
}

final class LoginFailureObserverSpy: LoginFailureObserver {
	var didNotifyFailure = false
	func didFailLogin(error: LoginError) {
		didNotifyFailure = true
	}
}
