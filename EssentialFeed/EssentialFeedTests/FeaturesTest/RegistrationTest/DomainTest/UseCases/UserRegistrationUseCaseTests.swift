import EssentialFeed
import Security
import XCTest

final class UserRegistrationUseCaseTests: XCTestCase {
	// MARK: - Helpers & Stubs
	final class UserRegistrationNotifierSpy: UserRegistrationNotifier {
		private(set) var notified = false
		private let onNotify: (() -> Void)?
		init(onNotify: (() -> Void)? = nil) {
			self.onNotify = onNotify
		}
		func notifyEmailAlreadyInUse() {
			notified = true
			onNotify?()
		}
	}
	
	final class RegistrationValidatorAlwaysValid: RegistrationValidatorProtocol {
		func validate(name: String, email: String, password: String) -> RegistrationValidationError? {
			return nil
		}
	}
	
	// Helpers locales solo si no existen globalmente (verifica en Helpers/KeychainFullSpy.swift y Helpers/anyURL.swift)
	// Si ya existen, elimina estos helpers locales y usa los globales.
	// Aquí solo dejo makeKeychainFullSpy y anyURL si no existen globalmente.
	func makeKeychainFullSpy() -> KeychainFullSpy {
		return KeychainFullSpy()
	}
	func anyURL() -> URL {
		return URL(string: "https://test-register-endpoint.com")!
	}
	// Elimina cualquier redefinición de trackForMemoryLeaks. Usa la global de XCTestCase.
	
	// MARK: - Tests
	
	func test_registerUser_withValidData_createsUserAndStoresCredentialsSecurely() async throws {
		let httpClient = HTTPClientSpy()
		let url = URL(string: "https://test-register-endpoint.com")!
		let response201 = HTTPURLResponse(
			url: url,
			statusCode: 201,
			httpVersion: nil,
			headerFields: nil
		)!
		let (sut, _, name, email, password, _) = makeSUTWithDefaults(httpClient: httpClient)
		
		let registerTask = Task {
			await sut.register(name: name, email: email, password: password)
		}
		let requestRegistered = expectation(description: "Request registered")
		Task {
			while httpClient.requests.isEmpty {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
			requestRegistered.fulfill()
		}
		await fulfillment(of: [requestRegistered], timeout: 1.0)
		httpClient.complete(with: Data(), response: response201)
		let result = await registerTask.value
		
		switch result {
			case .success(let user):
				XCTAssertEqual(user.name, name, "Registered user's name should match input")
				XCTAssertEqual(user.email, email, "Registered user's email should match input")
			case .failure:
				XCTFail("Expected success, got failure instead")
		}
	}
	
	func test_registerUser_withEmptyName_returnsValidationError_andDoesNotCallHTTPOrKeychain() async {
		await assertRegistrationValidation(
			name: "",
			email: "test@email.com",
			password: "Password123",
			expectedError: .emptyName
		)
	}
	
	func test_registerUser_withInvalidEmail_returnsValidationError_andDoesNotCallHTTPOrKeychain() async {
		await assertRegistrationValidation(
			name: "Test User",
			email: "invalid-email",
			password: "Password123",
			expectedError: .invalidEmail
		)
	}
	
	func test_registerUser_withWeakPassword_returnsValidationError_andDoesNotCallHTTPOrKeychain() async {
		await assertRegistrationValidation(
			name: "Test User",
			email: "test@email.com",
			password: "123",
			expectedError: .weakPassword
		)
	}
	
	func test_registerUser_withAlreadyRegisteredEmail_notifiesEmailAlreadyInUsePresenter() async {
		let httpClient = HTTPClientSpy()
		let notifierExpectation = expectation(description: "Notifier should be called")
		let notifier = UserRegistrationNotifierSpy {
			notifierExpectation.fulfill()
		}
		let (sut, keychain, name, email, password, _) = makeSUTWithDefaults(
			httpClient: httpClient,
			notifier: notifier
		)
		
		let registerTask = Task {
			await sut.register(name: name, email: email, password: password)
		}
		let requestRegistered = expectation(description: "Request registered")
		Task {
			while httpClient.requests.isEmpty {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
			requestRegistered.fulfill()
		}
		await fulfillment(of: [requestRegistered], timeout: 1.0)
		let response409 = HTTPURLResponse(url: httpClient.requests.first?.url ?? URL(string: "https://test-register-endpoint.com")!, statusCode: 409, httpVersion: nil, headerFields: nil)!
		httpClient.complete(with: Data(), response: response409)
		await fulfillment(of: [notifierExpectation], timeout: 1.0)
		let result = await registerTask.value
		
		XCTAssertTrue(notifier.notified, "Notifier should be called on registration")
		XCTAssertEqual(keychain.saveSpy.saveCallCount, 0, "Keychain save should not be called on registration failure")
		switch result {
			case .failure(let error as UserRegistrationError):
				XCTAssertEqual(error, .emailAlreadyInUse, "Expected .emailAlreadyInUse error")
			default:
				XCTFail("Expected .emailAlreadyInUse error, got \(result) instead")
		}
	}
	
	func test_registerUser_withAlreadyRegisteredEmail_returnsEmailAlreadyInUseError_andDoesNotStoreCredentials() async {
		let httpClient = HTTPClientSpy()
		let (sut, keychain, name, email, password, _) = makeSUTWithDefaults(httpClient: httpClient)
		
		let registerTask = Task {
			await sut.register(name: name, email: email, password: password)
		}
		let requestRegistered = expectation(description: "Request registered")
		Task {
			while httpClient.requests.isEmpty {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
			requestRegistered.fulfill()
		}
		await fulfillment(of: [requestRegistered], timeout: 1.0)
		let response409 = HTTPURLResponse(url: httpClient.requests.first?.url ?? URL(string: "https://test-register-endpoint.com")!, statusCode: 409, httpVersion: nil, headerFields: nil)!
		httpClient.complete(with: Data(), response: response409)
		let result = await registerTask.value
		
		switch result {
			case .failure(let error as UserRegistrationError):
				XCTAssertEqual(error, .emailAlreadyInUse, "Expected .emailAlreadyInUse error")
			default:
				XCTFail("Expected .emailAlreadyInUse error, got \(result) instead")
		}
		XCTAssertEqual(keychain.saveSpy.saveCallCount, 0, "No Keychain save should occur if email is already registered")
	}
	
	func test_registerUser_withNoConnectivity_returnsConnectivityError_andDoesNotStoreCredentials() async {
		let httpClient = HTTPClientSpy()
		let (sut, keychain, name, email, password, _) = makeSUTWithDefaults(httpClient: httpClient)
		let requestRegistered = expectation(description: "Request registered")
		
		Task {
			_ = await sut.register(name: name, email: email, password: password)
			requestRegistered.fulfill()
		}
		
		let start = Date()
		while httpClient.requests.isEmpty {
			if Date().timeIntervalSince(start) > 0.9 {
				XCTFail("HTTPClientSpy never received a request")
				break
			}
			try? await Task.sleep(nanoseconds: 10_000_000)
		}
		httpClient.complete(with: NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue, userInfo: nil))
		
		await fulfillment(of: [requestRegistered], timeout: 1.0)
		
		XCTAssertEqual(keychain.saveSpy.saveCallCount, 0, "No Keychain save should occur if there is no connectivity")
	}
	
	// MARK: - Debug Minimal Test
//	func test_registerUser_withNoConnectivity_minimal() async {
//		let httpClient = HTTPClientSpy()
//		let keychain = makeKeychainFullSpy()
//		let sut = UserRegistrationUseCase(
//			keychain: keychain,
//			validator: RegistrationValidatorAlwaysValid(),
//			httpClient: httpClient,
//			registrationEndpoint: URL(string: "https://test-register-endpoint.com")!
//		)
//		
//		print("TEST: SUT created")
//		
//		async let _ = sut.register(name: "Test", email: "test@gmail.com", password: "password")
//		
//		// Espera asíncrona a que el spy registre la request (máx 1s)
//		let timeout: UInt64 = 1_000_000_000 // 1 segundo en nanosegundos
//		let start = DispatchTime.now()
//		while httpClient.requests.isEmpty && DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds < timeout {
//			try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
//		}
//		
//		print("TEST: HTTPClientSpy requests count: \(httpClient.requests.count)")
//		XCTAssertEqual(httpClient.requests.count, 1, "Should have registered exactly one request")
//	}
	
	private func makeSUTWithDefaults(
		httpClient: HTTPClient = HTTPClientSpy(),
		notifier: UserRegistrationNotifier = UserRegistrationNotifierSpy(),
		name: String = "Test User",
		email: String = "test@email.com",
		password: String = "Password123",
		file: StaticString = #file, line: UInt = #line
	) -> (sut: UserRegistrationUseCase, keychain: KeychainFullSpy, name: String, email: String, password: String, notifier: UserRegistrationNotifier) {
		let keychain = makeKeychainFullSpy()
		let registrationEndpoint = URL(string: "https://test-register-endpoint.com")!
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			validator: RegistrationValidatorAlwaysValid(),
			httpClient: httpClient,
			registrationEndpoint: registrationEndpoint,
			notifier: notifier
		)
		trackForMemoryLeaks(keychain, file: file, line: line)
		trackForMemoryLeaks(sut, file: file, line: line)
		return (sut, keychain, name, email, password, notifier)
	}
	
	private func makeSUTWithKeychain(
		_ keychain: KeychainFullSpy,
		file: StaticString = #file,
		line: UInt = #line
	) -> (sut: UserRegistrationUseCase, name: String, email: String, password: String) {
		let name = "Carlos"
		let email = "carlos@email.com"
		let password = "StrongPassword123"
		let httpClient = HTTPClientDummy()
		let registrationEndpoint = URL(string: "https://test-register-endpoint.com")!
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			validator: RegistrationValidatorStub(),
			httpClient: httpClient,
			registrationEndpoint: registrationEndpoint
		)
		trackForMemoryLeaks(sut, file: #file, line: #line)
		trackForMemoryLeaks(keychain, file: #file, line: #line)
		return (sut, name, email, password)
	}
	
	private func assertRegistrationValidation(
		name: String,
		email: String,
		password: String,
		expectedError: RegistrationValidationError,
		file: StaticString = #file,
		line: UInt = #line
	) async {
		let keychain = makeKeychainFullSpy()
		let validator = RegistrationValidatorStub()
		let httpClient = HTTPClientSpy()
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			validator: validator,
			httpClient: httpClient,
			registrationEndpoint: anyURL()
		)
		
		let result = await sut.register(name: name, email: email, password: password)
		
		switch result {
			case .failure(let error as RegistrationValidationError):
				XCTAssertEqual(error, expectedError, file: #file, line: #line)
			default:
				XCTFail(
					"Expected failure with \(expectedError), got \(result) instead",
					file: #file,
					line: #line
				)
		}
		
		XCTAssertEqual(
			httpClient.requests.count,
			0,
			"No HTTP request should be made if validation fails",
			file: #file,
			line: #line
		)
		
		XCTAssertEqual(
			keychain.saveSpy.saveCallCount,
			0,
			"No Keychain save should occur if validation fails",
			file: #file,
			line: #line
		)
	}
	
}
