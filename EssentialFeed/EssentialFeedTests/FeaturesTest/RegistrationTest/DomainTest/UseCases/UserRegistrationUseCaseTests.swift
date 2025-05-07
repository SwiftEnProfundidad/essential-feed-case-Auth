import EssentialFeed
import Security
import XCTest

final class UserRegistrationUseCaseTests: XCTestCase {
	
	// MARK: - Tests
	
	func test_registerUser_withValidDataAndToken_createsUserStoresCredentialsAndToken() async throws {
		let httpClient = HTTPClientSpy()
		let tokenStorage = TokenStorageSpy()
		let url = anyURL()
		let response201 = HTTPURLResponse(
			url: url,
			statusCode: 201, // Registro exitoso
			httpVersion: nil,
			headerFields: nil
		)!
		let (sut, keychain, name, email, password, _, returnedTokenStorage, _) = makeSUTWithDefaults(httpClient: httpClient, tokenStorage: tokenStorage)
		let expectedTokenToReceiveAndStore = makeToken() // El token que esperamos que el servidor envíe
																										 // Crear los datos de respuesta del servidor que incluyen el token
		let serverResponseData = try makeRegistrationServerResponseData(name: name, email: email, token: expectedTokenToReceiveAndStore)
		
		let registerTask = Task {
			await sut.register(name: name, email: email, password: password)
		}
		
		// Await HTTP request
		await expectHTTPRequest(from: httpClient)
		
		// Simular que el servidor responde con los datos que incluyen el token
		httpClient.complete(with: serverResponseData, response: response201)
		let result = await registerTask.value
		
		switch result {
			case .success(let user):
				XCTAssertEqual(user.name, name, "Registered user's name should match input")
				XCTAssertEqual(user.email, email, "Registered user's email should match input")
				
				XCTAssertEqual(keychain.saveSpy.saveCallCount, 1, "Expected to save credentials once")
				XCTAssertEqual(keychain.saveSpy.lastKey, email, "Expected to save credentials for the correct email")
				XCTAssertEqual(keychain.saveSpy.lastData, password.data(using: .utf8), "Expected to save correct password data")
				
				XCTAssertEqual(returnedTokenStorage.messages.count, 1, "Expected to save token once")
				if case let .save(savedToken) = returnedTokenStorage.messages.first {
					XCTAssertEqual(savedToken, expectedTokenToReceiveAndStore, "Expected to save the correct token received from server")
				} else {
					XCTFail("Expected save message in TokenStorageSpy, got \(String(describing: returnedTokenStorage.messages.first))")
				}
			case .failure(let error):
				XCTFail("Expected success, got failure \(error) instead")
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
	
	func test_registerUser_withValidData_whenTokenStorageFails_returnsErrorAndDoesNotStoreCredentials() async throws {
		let httpClient = HTTPClientSpy()
		let tokenStorage = TokenStorageSpy()
		let url = anyURL()
		let response201 = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
		// MODIFY: makeSUT to include tokenStorage and adjust return tuple
		let (sut, keychain, name, email, password, _, returnedTokenStorage, _) = makeSUTWithDefaults(httpClient: httpClient, tokenStorage: tokenStorage)
		
		let tokenFromServer = makeToken()
		let serverResponseData = try makeRegistrationServerResponseData(name: name, email: email, token: tokenFromServer)
		
		let tokenStorageError = NSError(domain: "TokenStorageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to save token"])
		returnedTokenStorage.saveTokenError = tokenStorageError // Configurar el spy para que falle al guardar
		
		let registerTask = Task {
			await sut.register(name: name, email: email, password: password)
		}
		
		await expectHTTPRequest(from: httpClient)
		httpClient.complete(with: serverResponseData, response: response201) // Servidor responde OK con token
		let result = await registerTask.value
		
		switch result {
			case .success:
				XCTFail("Expected failure due to token storage error, got success instead")
			case .failure(let error):
				// Verificar que el error es el que propagó TokenStorage
				XCTAssertEqual(error as NSError, tokenStorageError, "Expected token storage error")
		}
		// Las credenciales no deberían guardarse si el guardado del token falla, para mantener la atomicidad de la operación "exitosa"
		XCTAssertEqual(keychain.saveSpy.saveCallCount, 0, "Keychain save should not be called if token storage fails")
		XCTAssertEqual(returnedTokenStorage.messages.count, 1, "Expected TokenStorage save to be attempted once")
		if case .save(let attemptedToken) = returnedTokenStorage.messages.first {
			XCTAssertEqual(attemptedToken, tokenFromServer, "Expected to attempt saving the correct token")
		} else {
			XCTFail("Expected save message in TokenStorageSpy, got \(String(describing: returnedTokenStorage.messages.first))")
		}
	}
	
	func test_registerUser_withValidData_whenServerResponseIsMissingOrMalformedToken_returnsError() async throws {
		let httpClient = HTTPClientSpy()
		let tokenStorage = TokenStorageSpy() // SUT necesitará el tokenStorage
		let url = anyURL()
		let response201 = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
		// MODIFY: makeSUT
		let (sut, keychain, name, email, password, _, returnedTokenStorage, _) = makeSUTWithDefaults(httpClient: httpClient, tokenStorage: tokenStorage)
		
		// Respuesta del servidor con JSON que no se puede parsear a la estructura esperada (ej. falta el campo "token")
		let malformedResponseData = Data(#"{"user": {"name": "Test User", "email": "test@email.com"}}"#.utf8)
		
		let registerTask = Task {
			await sut.register(name: name, email: email, password: password)
		}
		
		await expectHTTPRequest(from: httpClient)
		httpClient.complete(with: malformedResponseData, response: response201)
		let result = await registerTask.value
		
		switch result {
			case .success:
				XCTFail("Expected failure due to unparseable/missing token response, got success instead")
			case .failure(let error):
				// El error específico dependerá de cómo UserRegistrationUseCase maneje el fallo de parseo.
				// Podría ser un DecodingError o un error personalizado.
				XCTAssertTrue(error is DecodingError || (error as NSError).domain == "UserRegistrationUseCase.TokenParsingError", "Expected a parsing error or custom token error")
		}
		XCTAssertEqual(keychain.saveSpy.saveCallCount, 0, "Keychain save should not be called if token parsing fails")
		XCTAssertEqual(returnedTokenStorage.messages.count, 0, "TokenStorage save should not be attempted if token parsing fails")
	}
	
	func test_registerUser_withAlreadyRegisteredEmail_notifiesEmailAlreadyInUsePresenter() async {
		let httpClient = HTTPClientSpy()
		let notifierExpectation = expectation(description: "Notifier should be called for email in use")
		let notifier = UserRegistrationNotifierSpy {
			notifierExpectation.fulfill()
		}
		// Asumiendo que makeSUTWithDefaults inyecta el notifier correctamente.
		let (sut, keychain, name, email, password, _, _, _) = makeSUTWithDefaults(
			httpClient: httpClient,
			notifier: notifier
		)
		
		let registerTask = Task {
			return await sut.register(name: name, email: email, password: password)
		}
		
		await expectHTTPRequest(from: httpClient)
		
		let response409 = HTTPURLResponse(url: httpClient.requests.first?.url ?? anyURL(), statusCode: 409, httpVersion: nil, headerFields: nil)!
		httpClient.complete(with: Data(), response: response409)
		
		let result = await registerTask.value
		
		await fulfillment(of: [notifierExpectation], timeout: 1.0)
		
		XCTAssertTrue(notifier.notifiedEmailInUse, "Notifier should be called with emailAlreadyInUse error")
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
		let (sut, keychain, name, email, password, _, _, _) = makeSUTWithDefaults(httpClient: httpClient)
		
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
		let response409 = HTTPURLResponse(url: httpClient.requests.first?.url ?? anyURL(), statusCode: 409, httpVersion: nil, headerFields: nil)!
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
		let (sut, keychain, name, email, password, _, _, _) = makeSUTWithDefaults(httpClient: httpClient)
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
	
	func test_register_whenNoConnectivity_savesDataToOfflineStoreAndReturnsConnectivityError() async throws {
		print("--- test_register_whenNoConnectivity_savesDataToOfflineStoreAndReturnsConnectivityError START ---")
		let httpClient = HTTPClientSpy()
		let (sut, keychain, name, email, password, notifier, tokenStorage, offlineStore) = makeSUTWithDefaults(httpClient: httpClient)
		let expectedUserData = UserRegistrationData(name: name, email: email, password: password)
		
		let registerTask = Task {
			print("test_register_whenNoConnectivity: Calling sut.register")
			let res = await sut.register(name: name, email: email, password: password)
			print("test_register_whenNoConnectivity: sut.register returned \(res)")
			return res
		}
		
		print("test_register_whenNoConnectivity: Waiting for HTTP request")
		await expectHTTPRequest(from: httpClient)
		print("test_register_whenNoConnectivity: HTTP request received by spy. Completing with error.")
		httpClient.complete(with: NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue))
		
		print("test_register_whenNoConnectivity: Awaiting registerTask.value")
		let result = await registerTask.value
		print("test_register_whenNoConnectivity: registerTask.value received. Result: \(result)")
		
		XCTAssertEqual(offlineStore.messages.count, 1, "Expected to save data once to offline store")
		if let firstMessage = offlineStore.messages.first {
			switch firstMessage {
				case .save(let savedData):
					XCTAssertEqual(savedData, expectedUserData, "Expected to save correct user data to offline store")
			}
		} else {
			XCTFail("Expected .save message in offlineStore, but messages array is empty.")
		}
		
		switch result {
			case .failure(let error as NetworkError):
				XCTAssertEqual(error, .noConnectivity, "Expected noConnectivity error")
			default:
				XCTFail("Expected noConnectivity error, got \(String(describing: result)) instead")
		}
		
		if let notifierSpy = notifier as? UserRegistrationNotifierSpy {
			XCTAssertTrue(notifierSpy.notifiedConnectivityError, "Notifier should be called with noConnectivity error")
		} else {
			XCTFail("Notifier is not a UserRegistrationNotifierSpy instance")
		}
		
		XCTAssertEqual(keychain.saveSpy.saveCallCount, 0, "Keychain save should not be called on connectivity error")
		XCTAssertTrue(tokenStorage.messages.isEmpty, "TokenStorage save should not be called on connectivity error")
		
		print("--- test_register_whenNoConnectivity_savesDataToOfflineStoreAndReturnsConnectivityError END ---")
	}
	
	private func makeSUTWithDefaults(
		httpClient: HTTPClient = HTTPClientSpy(),
		tokenStorage: TokenStorage = TokenStorageSpy(),
		offlineStore: OfflineRegistrationStore = OfflineRegistrationStoreSpy(),
		notifier: UserRegistrationNotifier = UserRegistrationNotifierSpy(),
		name: String = "Test User",
		email: String = "test@email.com",
		password: String = "Password123",
		file: StaticString = #file, line: UInt = #line
	) -> (sut: UserRegistrationUseCase, keychain: KeychainFullSpy, name: String, email: String, password: String, notifier: UserRegistrationNotifier, tokenStorage: TokenStorageSpy, offlineStore: OfflineRegistrationStoreSpy) {
		let keychain = makeKeychainFullSpy()
		let registrationEndpoint = anyURL()
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			tokenStorage: tokenStorage,
			offlineStore: offlineStore,
			validator: RegistrationValidatorAlwaysValid(),
			httpClient: httpClient,
			registrationEndpoint: registrationEndpoint,
			notifier: notifier
		)
		trackForMemoryLeaks(keychain, file: file, line: line)
		trackForMemoryLeaks(sut, file: file, line: line)
		if let tokenStorageSpy = tokenStorage as? TokenStorageSpy {
			trackForMemoryLeaks(tokenStorageSpy, file: file, line: line)
		}
		if let offlineStoreSpy = offlineStore as? OfflineRegistrationStoreSpy {
			trackForMemoryLeaks(offlineStoreSpy, file: file, line: line)
		}
		return (sut, keychain, name, email, password, notifier, tokenStorage as! TokenStorageSpy, offlineStore as! OfflineRegistrationStoreSpy)
	}
	
	private func makeSUTWithKeychain(
		_ keychain: KeychainFullSpy,
		tokenStorage: TokenStorage = TokenStorageSpy(),
		offlineStore: OfflineRegistrationStore = OfflineRegistrationStoreSpy(),
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
			tokenStorage: tokenStorage,
			offlineStore: offlineStore,
			validator: RegistrationValidatorStub(),
			httpClient: httpClient,
			registrationEndpoint: registrationEndpoint
		)
		trackForMemoryLeaks(sut, file: file, line: line)
		trackForMemoryLeaks(keychain, file: file, line: line)
		
		if let tokenStorageSpy = tokenStorage as? TokenStorageSpy {
			trackForMemoryLeaks(tokenStorageSpy, file: file, line: line)
		}
		if let offlineStoreSpy = offlineStore as? OfflineRegistrationStoreSpy {
			trackForMemoryLeaks(offlineStoreSpy, file: file, line: line)
		}
		return (sut, name, email, password)
	}
	
	private func assertRegistrationValidation(
		name: String,
		email: String,
		password: String,
		expectedError: RegistrationValidationError,
		offlineStore: OfflineRegistrationStore = OfflineRegistrationStoreSpy(),
		file: StaticString = #file,
		line: UInt = #line
	) async {
		print("--- assertRegistrationValidation START ---")
		print("Input: name='\(name)', email='\(email)', password='\(password)', expectedError='\(expectedError)'")
		
		let keychain = makeKeychainFullSpy()
		let validator = RegistrationValidatorStub() // Creamos el stub
		validator.errorToReturn = expectedError    // <<-- CRUCIAL: Configurar el stub para que devuelva el error esperado
		
		let httpClient = HTTPClientSpy()
		let tokenStorage = TokenStorageSpy()
		
		print("Creating SUT for assertRegistrationValidation")
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			tokenStorage: tokenStorage,
			offlineStore: offlineStore,
			validator: validator, // Usar el stub configurado
			httpClient: httpClient,
			registrationEndpoint: anyURL()
		)
		
		if let offlineStoreSpy = offlineStore as? OfflineRegistrationStoreSpy {
			trackForMemoryLeaks(offlineStoreSpy, file: file, line: line)
		}
		trackForMemoryLeaks(validator as AnyObject, file: file, line: line) // validator es una clase
		trackForMemoryLeaks(keychain, file: file, line: line)
		trackForMemoryLeaks(httpClient, file: file, line: line)
		trackForMemoryLeaks(tokenStorage, file: file, line: line)
		trackForMemoryLeaks(sut, file: file, line: line)
		
		print("Calling sut.register in assertRegistrationValidation")
		let result = await sut.register(name: name, email: email, password: password)
		print("sut.register returned: \(result)")
		
		switch result {
			case .failure(let error as RegistrationValidationError):
				XCTAssertEqual(error, expectedError, "Expected validation error \(expectedError), got \(error)", file: file, line: line)
			default:
				XCTFail("Expected failure with \(expectedError), got \(result) instead", file: file, line: line)
		}
		
		XCTAssertEqual(httpClient.requests.count, 0, "No HTTP request should be made if validation fails", file: file, line: line)
		XCTAssertEqual(keychain.saveSpy.saveCallCount, 0, "No Keychain save should occur if validation fails", file: file, line: line)
		XCTAssertTrue(tokenStorage.messages.isEmpty, "No TokenStorage interaction should occur if validation fails", file: file, line: line)
		if let offlineStoreSpy = offlineStore as? OfflineRegistrationStoreSpy {
			XCTAssertTrue(offlineStoreSpy.messages.isEmpty, "No OfflineRegistrationStore interaction should occur if validation fails", file: file, line: line)
		}
		print("--- assertRegistrationValidation END ---")
	}
	
	private func expectHTTPRequest(from httpClient: HTTPClientSpy, timeout: TimeInterval = 1.0, file: StaticString = #file, line: UInt = #line) async {
		let expectation = XCTestExpectation(description: "Wait for HTTP request from \(file):\(line)")
		let task = Task {
			for _ in 0..<100 {
				if !httpClient.requests.isEmpty {
					expectation.fulfill()
					return
				}
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		}
		
		await fulfillment(of: [expectation], timeout: timeout)
		task.cancel()
		
		if httpClient.requests.isEmpty {
			XCTFail("HTTPClientSpy never received a request within timeout", file: file, line: line)
		}
	}
	
	private func makeSUT(
		offlineStore: OfflineRegistrationStore = OfflineRegistrationStoreSpy(),
		file: StaticString = #file, line: UInt = #line
	) -> (sut: UserRegistrationUseCase, httpClient: HTTPClientSpy) {
		let httpClient = HTTPClientSpy()
		let tokenStorage = TokenStorageSpy()
		
		let sut = UserRegistrationUseCase(
			keychain: makeKeychainFullSpy(),
			tokenStorage: tokenStorage,
			offlineStore: offlineStore,
			validator: RegistrationValidatorStub(),
			httpClient: httpClient,
			registrationEndpoint: URL(string: "https://test-register-endpoint.com")!,
			notifier: nil
		)
		if let offlineStoreSpy = offlineStore as? OfflineRegistrationStoreSpy {
			trackForMemoryLeaks(offlineStoreSpy, file: file, line: line)
		}
		return (sut, httpClient)
	}
	
	final class OfflineRegistrationStoreSpy: OfflineRegistrationStore {
		enum Message: Equatable {
			case save(UserRegistrationData)
		}
		
		private(set) var messages = [Message]()
		var saveError: Error?
		
		func save(_ data: UserRegistrationData) async throws {
			if let error = saveError {
				throw error
			}
			messages.append(.save(data))
		}
	}
	
	func makeKeychainFullSpy() -> KeychainFullSpy {
		return KeychainFullSpy()
	}
	func anyURL() -> URL {
		return URL(string: "https://test-register-endpoint.com")!
	}
	
	private func makeToken(value: String = "any-test-token", expiryOffset: TimeInterval = 3600) -> EssentialFeed.Token {
		return EssentialFeed.Token(value: value, expiry: Date().addingTimeInterval(expiryOffset))
	}
	
	private func makeRegistrationServerResponseData(name: String, email: String, token: EssentialFeed.Token) throws -> Data {
		struct RegistrationServerResponse: Codable {
			struct UserPayload: Codable {
				let name: String
				let email: String
			}
			struct TokenPayload: Codable {
				let value: String
				let expiry: Date
			}
			let user: UserPayload
			let token: TokenPayload
		}
		
		let responsePayload = RegistrationServerResponse(
			user: .init(name: name, email: email),
			token: .init(value: token.value, expiry: token.expiry)
		)
		
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		return try encoder.encode(responsePayload)
	}
	
	// MARK: - Helpers & Stubs
	final class UserRegistrationNotifierSpy: UserRegistrationNotifier {
		
		private(set) var receivedErrors = [Error]()
		var notifiedEmailInUse: Bool {
			receivedErrors.contains { ($0 as? UserRegistrationError) == .emailAlreadyInUse }
		}
		var notifiedConnectivityError: Bool {
			receivedErrors.contains { ($0 as? NetworkError) == .noConnectivity }
		}
		var wasNotified: Bool {
			!receivedErrors.isEmpty
		}
		
		private let onNotify: (() -> Void)?
		
		init(onNotify: (() -> Void)? = nil) {
			self.onNotify = onNotify
		}
		
		
		func notifyRegistrationFailed(with error: Error) {
			receivedErrors.append(error)
			if (error as? UserRegistrationError) == .emailAlreadyInUse {
				onNotify?()
			}
		}
	}
	
	final class RegistrationValidatorAlwaysValid: RegistrationValidatorProtocol {
		func validate(name: String, email: String, password: String) -> RegistrationValidationError? {
			return nil
		}
	}
	
	final class RegistrationValidatorStub: RegistrationValidatorProtocol {
		var errorToReturn: RegistrationValidationError?
		init(errorToReturn: RegistrationValidationError? = nil) {
			self.errorToReturn = errorToReturn
		}
		func validate(name: String, email: String, password: String) -> RegistrationValidationError? {
			print("RegistrationValidatorStub.validate called. Will return: \(String(describing: errorToReturn))")
			return errorToReturn
		}
	}
}
