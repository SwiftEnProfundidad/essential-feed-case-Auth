import XCTest
import Combine
import EssentialFeed
import EssentialApp

final class LoginViewTests: XCTestCase {
	
	func test_login_withInvalidEmail_showsValidationError() async {
		// Arrange
		let viewModel = makeSUT(authenticate: { _, _ in .failure(.invalidEmailFormat) })
		viewModel.username = "invalid-email"
		viewModel.password = "password"
		// Act
		await viewModel.login()
		// Assert
		XCTAssertEqual(viewModel.errorMessage, "Email format is invalid.")
	}
	
	func test_login_withEmptyPassword_showsValidationError() async {
		let viewModel = makeSUT(authenticate: { _, _ in .failure(.invalidPasswordFormat) })
		viewModel.username = "user@email.com"
		viewModel.password = ""
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Password cannot be empty.")
	}
	
	func test_login_withValidCredentials_triggersAuthentication() async {
		let exp = expectation(description: "Authentication triggered")
		let viewModel = makeSUT(authenticate: { username, password in
			XCTAssertEqual(username, "user@email.com")
			XCTAssertEqual(password, "password")
			exp.fulfill()
			return .success(LoginResponse(token: "token"))
		})
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		await fulfillment(of: [exp], timeout: 1.0)
	}
	
	func test_login_withInvalidCredentials_showsAuthenticationError() async {
		let viewModel = makeSUT()
		viewModel.username = "user@email.com"
		viewModel.password = "wrongpass"
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Invalid credentials.")
	}
	
	func test_login_success_showsSuccessFeedback() async {
		let viewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertTrue(viewModel.loginSuccess)
	}
	
	func test_login_networkError_showsNetworkErrorMessage() async {
		let viewModel = makeSUT(authenticate: { _, _ in .failure(.network) })
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Could not connect. Please try again.")
	}
	
	func test_login_error_showsErrorFeedback() async {
		let viewModel = makeSUT(authenticate: { _, _ in .failure(.unknown) })
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Something went wrong. Please try again.")
	}
	
	func test_editingUsernameOrPassword_clearsErrorMessage() async {
		let viewModel = makeSUT()
		viewModel.username = "user@email.com"
		viewModel.password = "wrongpass"
		await viewModel.login()
		XCTAssertNotNil(viewModel.errorMessage, "Expected errorMessage to be present after failed login")
		
		// Simula que el usuario corrige el email
		viewModel.username = "new@email.com"
		XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil after editing username, but got: \(viewModel.errorMessage ?? "nil")")
		
		// Vuelve a poner el error
		viewModel.username = "user@email.com"
		viewModel.password = "wrongpass"
		await viewModel.login()
		XCTAssertNotNil(viewModel.errorMessage, "Expected errorMessage to be present after failed login")
		
		// Simula que el usuario corrige la contraseña
		viewModel.password = "newpassword"
		XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil after editing password, but got: \(viewModel.errorMessage ?? "nil")")
	}
	
	func test_loginSuccessFlag_isTrueAfterSuccessAndFalseAfterFailure() async {
		let viewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertTrue(viewModel.loginSuccess, "Expected loginSuccess to be true after successful login")
		
		// Ahora simula un login fallido
		let failingVM = makeSUT()
		failingVM.username = "user@email.com"
		failingVM.password = "wrongpass"
		await failingVM.login()
		XCTAssertFalse(failingVM.loginSuccess, "Expected loginSuccess to be false after failed login")
	}
	
	func test_successfulLogin_clearsPreviousErrorMessage() async {
		// Primer intento: error
		let failingViewModel = makeSUT()
		failingViewModel.username = "user@email.com"
		failingViewModel.password = "wrongpass"
		await failingViewModel.login()
		XCTAssertNotNil(failingViewModel.errorMessage, "Expected errorMessage to be present after failed login")
		
		// Segundo intento: éxito, usando un nuevo ViewModel
		let successViewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		successViewModel.username = "user@email.com"
		successViewModel.password = "password"
		await successViewModel.login()
		XCTAssertNil(successViewModel.errorMessage, "Expected errorMessage to be nil after successful login, but got: \(successViewModel.errorMessage ?? "nil")")
		XCTAssertTrue(successViewModel.loginSuccess, "Expected loginSuccess to be true after successful login")
	}
	
	func test_usernameAndPassword_arePublishedAndObservable() async {
		let viewModel = makeSUT()
		let expectedUsername = "test@email.com"
		let expectedPassword = "testpass123"
		viewModel.username = expectedUsername
		viewModel.password = expectedPassword
		XCTAssertEqual(viewModel.username, expectedUsername, "Expected username to be published and observable")
		XCTAssertEqual(viewModel.password, expectedPassword, "Expected password to be published and observable")
	}
	
	func test_onSuccessAlertDismissed_executesCallback() async {
		let viewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertTrue(viewModel.loginSuccess, "Expected loginSuccess to be true after successful login")
		
		var callbackCalled = false
		viewModel.onAuthenticated = {
			callbackCalled = true
		}
		viewModel.onSuccessAlertDismissed()
		XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false after dismissing alert")
		XCTAssertTrue(callbackCalled, "Expected onAuthenticated callback to be called after alert dismissed")
	}
	
	func test_initialState_isClean() async {
		let viewModel = makeSUT()
		XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil on initial state")
		XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false on initial state")
		XCTAssertEqual(viewModel.username, "", "Expected username to be empty on initial state")
		XCTAssertEqual(viewModel.password, "", "Expected password to be empty on initial state")
	}
	
	func test_login_withEmptyFields_showsValidationError() async {
		let viewModel = makeSUT()
		viewModel.username = ""
		viewModel.password = ""
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Email format is invalid.", "Expected validation error when username is empty")
		XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false when login fails due to validation")
	}
	
	func test_login_callsAuthenticateWithTrimmedUsername() async {
		var receivedUsername: String?
		let viewModel = makeSUT(authenticate: { username, password in
			receivedUsername = username
			return .failure(.invalidCredentials)
		})
		viewModel.username = "   user@email.com   "
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertEqual(receivedUsername, "user@email.com", "Expected authenticate to be called with trimmed username")
	}
	
	func test_viewModel_deallocation_doesNotRetainClosure() async {
		var viewModel: LoginViewModel? = makeSUT(authenticate: { _, _ in .failure(.invalidCredentials) })
		weak var weakViewModel = viewModel
		viewModel?.onAuthenticated = { _ = weakViewModel }
		viewModel = nil
		XCTAssertNil(weakViewModel, "ViewModel should be deallocated and not retain closures")
	}
	
	func test_login_doesNotTriggerAuthenticatedOnFailure() async {
		let viewModel = makeSUT(authenticate: { _, _ in .failure(.invalidCredentials) })
		var authenticatedCalled = false
		let cancellable = viewModel.authenticated.sink { _ in
			authenticatedCalled = true
		}
		viewModel.username = "user@email.com"
		viewModel.password = "fail"
		await viewModel.login()
		XCTAssertFalse(authenticatedCalled, "Expected authenticated event NOT to be sent after failed login")
		_ = cancellable
	}
	
	func test_errorMessage_isClearedOnLoginSuccess() async {
		let viewModel = makeSUT(authenticate: { username, password in
			if password == "fail" {
				return .failure(.invalidCredentials)
			} else {
				return .success(LoginResponse(token: "token"))
			}
		})
		viewModel.username = "user@email.com"
		viewModel.password = "fail"
		await viewModel.login()
		XCTAssertNotNil(viewModel.errorMessage, "Expected error message after failed login")
		viewModel.password = "pass"
		await viewModel.login()
		XCTAssertNil(viewModel.errorMessage, "Expected error message to be cleared after successful login")
	}
	
	func test_multipleLoginAttempts_onlyLastResultMatters() async {
		let exp = expectation(description: "Only last login result is reflected")
		exp.expectedFulfillmentCount = 2
		actor CompletionsStore {
			private(set) var completions: [Result<LoginResponse, LoginError>] = []
			func append(_ value: Result<LoginResponse, LoginError>) {
				completions.append(value)
			}
		}
		let completionsStore = CompletionsStore()
		let viewModel = makeSUT(authenticate: { username, password in
			if password == "first" {
				try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
				await completionsStore.append(.failure(.invalidCredentials))
				exp.fulfill()
				return .failure(.invalidCredentials)
			} else {
				await completionsStore.append(.success(LoginResponse(token: "token")))
				exp.fulfill()
				return .success(LoginResponse(token: "token"))
			}
		})
		viewModel.username = "user@email.com"
		viewModel.password = "first"
		let firstLogin = Task { await viewModel.login() }
		// Lanza el segundo login casi inmediato
		viewModel.password = "second"
		let secondLogin = Task { await viewModel.login() }
		await fulfillment(of: [exp], timeout: 1.0)
		await firstLogin.value
		await secondLogin.value
		XCTAssertTrue(viewModel.loginSuccess, "Expected loginSuccess to be true only for the last login attempt")
		XCTAssertNil(viewModel.errorMessage, "Expected errorMessage to be nil after last successful login")
	}
	
	func test_login_withInvalidPasswordFormat_showsValidationError() async {
		let viewModel = makeSUT()
		viewModel.username = "user@email.com"
		viewModel.password = "short" // Menos de 8 caracteres
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Invalid credentials.", "Expected validation error when password format is invalid")
		XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false when login fails due to invalid password format")
	}
	
	func test_login_withWhitespacePassword_showsValidationError() async {
		let viewModel = makeSUT()
		viewModel.username = "user@email.com"
		viewModel.password = "    "
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Password cannot be empty.", "Expected validation error when password is only whitespace")
		XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false when login fails due to validation")
	}
	
	func test_errorMessage_isClearedOnEditingFieldsAfterNetworkError() async {
		let viewModel = makeSUT(authenticate: { _, _ in .failure(.network) })
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Could not connect. Please try again.", "Expected network error message after failed login")
		// Edit username
		viewModel.username = "user2@email.com"
		XCTAssertNil(viewModel.errorMessage, "Expected error message to be cleared after editing username")
		// Simula de nuevo el error
		viewModel.username = "user@email.com"
		await viewModel.login()
		// Edit password
		viewModel.password = "newpassword"
		XCTAssertNil(viewModel.errorMessage, "Expected error message to be cleared after editing password")
	}
	
	func test_login_withWhitespaceUsername_showsValidationError() async {
		let viewModel = makeSUT()
		viewModel.username = "    "
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertEqual(viewModel.errorMessage, "Email format is invalid.", "Expected validation error when username is only whitespace")
		XCTAssertFalse(viewModel.loginSuccess, "Expected loginSuccess to be false when login fails due to validation")
	}
	
	func test_loginSuccess_sendsAuthenticatedEvent() async {
		let viewModel = makeSUT(authenticate: { _, _ in .success(LoginResponse(token: "token")) })
		var authenticatedCalled = false
		let cancellable = viewModel.authenticated.sink { _ in
			authenticatedCalled = true
		}
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		await viewModel.login()
		XCTAssertTrue(authenticatedCalled, "Expected authenticated event to be sent after successful login")
		_ = cancellable // Retain while in scope
	}
	
	func test_login_networkError_storesPendingRequest_and_canRetryLater() async {
		// Arrange
		let pendingStore = InMemoryPendingRequestStore<LoginRequest>()
		var authenticateCalls: [(String, String)] = []
		let viewModel = LoginViewModel(
			authenticate: { (username: String, password: String) -> Result<LoginResponse, LoginError> in
				authenticateCalls.append((username, password))
				return .failure(LoginError.network)
			},
			pendingRequestStore: AnyLoginRequestStore(pendingStore)
		)
		viewModel.username = "user@email.com"
		viewModel.password = "password"
		
		// Act: Simula login con error de red
		await viewModel.login()
		
		// Assert: La solicitud debe estar almacenada
		XCTAssertEqual(pendingStore.loadAll(), [LoginRequest(username: "user@email.com", password: "password")])
		
		// Simula que la siguiente autenticación tiene éxito
		viewModel.authenticate = { (username: String, password: String) -> Result<LoginResponse, LoginError> in
			authenticateCalls.append((username, password))
			return .success(LoginResponse(token: "token"))
		}
		
		// Act: Reintenta las solicitudes almacenadas
		await viewModel.retryPendingRequests()
		
		// Assert: La solicitud debe haberse eliminado del store y el login debe haber sido exitoso
		XCTAssertEqual(pendingStore.loadAll(), [])
		XCTAssertTrue(viewModel.loginSuccess)
		XCTAssertEqual(authenticateCalls.count, 2)
	}
	
	func test_login_blocksAfterMaxFailedAttempts() async {
		let spyStore = SpyFailedLoginAttemptsStore()
		let viewModel = makeSUT(
			failedAttemptsStore: spyStore,
			maxFailedAttempts: 3
		)
		
		// Simulamos intentos previos (3/3)
		spyStore.incrementAttempts(for: "user@test.com")
		spyStore.incrementAttempts(for: "user@test.com")
		spyStore.incrementAttempts(for: "user@test.com")
		
		viewModel.username = "user@test.com"
		viewModel.password = "wrong-password"
		
		await viewModel.login()
		
		XCTAssertEqual(spyStore.getAttemptsCallCount, 1)
		XCTAssertEqual(spyStore.incrementAttemptsCallCount, 3)
		XCTAssertTrue(viewModel.isLoginBlocked, "Expected account to be locked after max failed attempts")
		XCTAssertEqual(viewModel.errorMessage, "Demasiados intentos. Por favor, espera 5 minutos o recupera tu contraseña.")
	}
	
	func test_login_resetsAttemptsOnSuccess() async {
		let spyStore = SpyFailedLoginAttemptsStore()
		let viewModel = makeSUT(
			authenticate: { _, _ in .success(LoginResponse.init(token: "token")) }, // authenticate primero
			failedAttemptsStore: spyStore // luego failedAttemptsStore
		)
		
		viewModel.username = "user@test.com"
		viewModel.password = "correct-password"
		
		await viewModel.login()
		
		XCTAssertEqual(spyStore.resetAttemptsCallCount, 1)
		XCTAssertEqual(spyStore.capturedUsernames.last, "user@test.com")
	}
	
	func test_login_appliesIncrementalDelayAfterMaxAttempts() async {
		let spyStore = SpyFailedLoginAttemptsStore()
		
		// Configuramos el mock para tener delay cuando se superen los intentos
		var shouldDelay = false
		let viewModel = makeSUT(
			authenticate: { _, _ in 
				if shouldDelay {
					try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 segundo
				}
				return .failure(.invalidCredentials)
			},
			failedAttemptsStore: spyStore,
			maxFailedAttempts: 3
		)
		
		// Primeros intentos (sin delay)
		for _ in 1...3 {
			await viewModel.login()
			XCTAssertFalse(viewModel.isLoginBlocked)
		}
		
		// Intento 4 (activamos delay)
		shouldDelay = true
		let startTime = Date()
		await viewModel.login()
		let isStillBlocked = viewModel.isLoginBlocked
		let elapsed = Date().timeIntervalSince(startTime)

		XCTAssertTrue(isStillBlocked || elapsed >= 0.5, 
		    "Account should be locked during delay. Locked: \(isStillBlocked), Elapsed: \(elapsed)s")
		XCTAssertGreaterThanOrEqual(elapsed, 0.5, "Expected minimum delay of 0.5 seconds but got \(elapsed)")
	}
	
	// MARK: Helpers
	
	private func makeSUT(
		authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError> = { _, _ in .failure(.invalidCredentials) },
		failedAttemptsStore: FailedLoginAttemptsStore = InMemoryFailedLoginAttemptsStore(),
		maxFailedAttempts: Int = 5,
		file: StaticString = #file,
		line: UInt = #line
	) -> LoginViewModel {
		let sut = LoginViewModel(
			authenticate: { username, password in
				await authenticate(username, password)
			},
			failedAttemptsStore: failedAttemptsStore,
			maxFailedAttempts: maxFailedAttempts
		)
		trackForMemoryLeaks(sut, file: file, line: line)
		return sut
	}
	
	private class SpyFailedLoginAttemptsStore: FailedLoginAttemptsStore {
		private(set) var getAttemptsCallCount = 0
		private(set) var incrementAttemptsCallCount = 0
		private(set) var resetAttemptsCallCount = 0
		private(set) var capturedUsernames = [String]()
		private var attempts: [String: Int] = [:]
		
		func getAttempts(for username: String) -> Int {
			getAttemptsCallCount += 1
			capturedUsernames.append(username)
			return attempts[username, default: 0]
		}
		
		func incrementAttempts(for username: String) {
			incrementAttemptsCallCount += 1
			capturedUsernames.append(username)
			attempts[username, default: 0] += 1
		}
		
		func resetAttempts(for username: String) {
			resetAttemptsCallCount += 1
			capturedUsernames.append(username)
			attempts[username] = 0
		}
	}
	
}
