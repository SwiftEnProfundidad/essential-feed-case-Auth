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
	
	// MARK: - Tests
	
	private func makeToken(value: String = "any-test-token", expiryOffset: TimeInterval = 3600) -> EssentialFeed.Token {
		return EssentialFeed.Token(value: value, expiry: Date().addingTimeInterval(expiryOffset))
	}
	
	private func makeRegistrationServerResponseData(name: String, email: String, token: EssentialFeed.Token) throws -> Data {
		// Define una estructura que coincida con la respuesta esperada del servidor
		struct RegistrationServerResponse: Codable {
			struct UserPayload: Codable { // Renombrado para evitar colisión con User global
				let name: String
				let email: String
			}
			struct TokenPayload: Codable { // Renombrado para evitar colisión con Token global
				let value: String
				let expiry: Date // Asegúrate de que el formato de fecha sea compatible con JSONEncoder/Decoder
			}
			let user: UserPayload
			let token: TokenPayload
		}
		
		let responsePayload = RegistrationServerResponse(
			user: .init(name: name, email: email),
			token: .init(value: token.value, expiry: token.expiry)
		)
		
		let encoder = JSONEncoder()
		// Configura la estrategia de codificación de fechas si es necesario, ej: .iso8601
		encoder.dateEncodingStrategy = .iso8601 // Común para APIs REST
		return try encoder.encode(responsePayload)
	}
	
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
		// MODIFY: makeSUT to include tokenStorage and adjust return tuple
		let (sut, keychain, name, email, password, _, returnedTokenStorage) = makeSUTWithDefaults(httpClient: httpClient, tokenStorage: tokenStorage)
		
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
		let (sut, keychain, name, email, password, _, returnedTokenStorage) = makeSUTWithDefaults(httpClient: httpClient, tokenStorage: tokenStorage)
		
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
		let (sut, keychain, name, email, password, _, returnedTokenStorage) = makeSUTWithDefaults(httpClient: httpClient, tokenStorage: tokenStorage)
		
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
		let notifierExpectation = expectation(description: "Notifier should be called")
		let notifier = UserRegistrationNotifierSpy {
			notifierExpectation.fulfill()
		}
		let (sut, keychain, name, email, password, _, _) = makeSUTWithDefaults(
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
		let (sut, keychain, name, email, password, _, _) = makeSUTWithDefaults(httpClient: httpClient)
		
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
		let (sut, keychain, name, email, password, _, _) = makeSUTWithDefaults(httpClient: httpClient)
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
	
	private func makeSUTWithDefaults(
		httpClient: HTTPClient = HTTPClientSpy(),
		tokenStorage: TokenStorage = TokenStorageSpy(),
		notifier: UserRegistrationNotifier = UserRegistrationNotifierSpy(),
		name: String = "Test User",
		email: String = "test@email.com",
		password: String = "Password123",
		file: StaticString = #file, line: UInt = #line
	) -> (sut: UserRegistrationUseCase, keychain: KeychainFullSpy, name: String, email: String, password: String, notifier: UserRegistrationNotifier, tokenStorage: TokenStorageSpy) { // MODIFY: return tuple to include TokenStorageSpy
		let keychain = makeKeychainFullSpy()
		let registrationEndpoint = anyURL()
		// El UserRegistrationUseCase necesitará ser modificado para aceptar tokenStorage en su init
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			tokenStorage: tokenStorage, // Pasar el tokenStorage al init
			validator: RegistrationValidatorAlwaysValid(),
			httpClient: httpClient,
			registrationEndpoint: registrationEndpoint,
			notifier: notifier
		)
		trackForMemoryLeaks(keychain, file: file, line: line)
		trackForMemoryLeaks(sut, file: file, line: line)
		// Asegurarse de que tokenStorage es un TokenStorageSpy para el trackeo y el retorno
		if let tokenStorageSpy = tokenStorage as? TokenStorageSpy {
			trackForMemoryLeaks(tokenStorageSpy, file: file, line: line)
		}
		// Devolver el tokenStorage como TokenStorageSpy para poder acceder a sus propiedades de spy (messages, stubs)
		return (sut, keychain, name, email, password, notifier, tokenStorage as! TokenStorageSpy)
	}
	
	private func makeSUTWithKeychain(
		_ keychain: KeychainFullSpy,
		tokenStorage: TokenStorage = TokenStorageSpy(),
		file: StaticString = #file,
		line: UInt = #line
	) -> (sut: UserRegistrationUseCase, name: String, email: String, password: String) {
		let name = "Carlos"
		let email = "carlos@email.com"
		let password = "StrongPassword123"
		let httpClient = HTTPClientDummy() // Asumimos que HTTPClientDummy es suficiente para los tests que usan este SUT
		let registrationEndpoint = URL(string: "https://test-register-endpoint.com")!
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			tokenStorage: tokenStorage,
			validator: RegistrationValidatorStub(), // Asumimos que RegistrationValidatorStub es suficiente
			httpClient: httpClient,
			registrationEndpoint: registrationEndpoint
		)
		trackForMemoryLeaks(sut, file: file, line: line) // Corregido #file y #line
		trackForMemoryLeaks(keychain, file: file, line: line) // Corregido #file y #line
		
		if let tokenStorageSpy = tokenStorage as? TokenStorageSpy {
			trackForMemoryLeaks(tokenStorageSpy, file: file, line: line)
		}
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
		let tokenStorage = TokenStorageSpy()
		
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			tokenStorage: tokenStorage,
			validator: validator,
			httpClient: httpClient,
			registrationEndpoint: anyURL()
		)
		trackForMemoryLeaks(tokenStorage, file: file, line: line)
		
		let result = await sut.register(name: name, email: email, password: password)
		
		switch result {
			case .failure(let error as RegistrationValidationError):
				XCTAssertEqual(error, expectedError, file: file, line: line)
			default:
				XCTFail(
					"Expected failure with \(expectedError), got \(result) instead",
					file: file,
					line: line
				)
		}
		
		XCTAssertEqual(
			httpClient.requests.count,
			0,
			"No HTTP request should be made if validation fails",
			file: file,
			line: line
		)
		
		XCTAssertEqual(
			keychain.saveSpy.saveCallCount,
			0,
			"No Keychain save should occur if validation fails",
			file: file,
			line: line
		)
		
		XCTAssertTrue(tokenStorage.messages.isEmpty, "No TokenStorage interaction should occur if validation fails", file: file, line: line)
	}
	
	private func expectHTTPRequest(from httpClient: HTTPClientSpy, timeout: TimeInterval = 1.0, file: StaticString = #file, line: UInt = #line) async {
		let expectation = XCTestExpectation(description: "Wait for HTTP request from \(file):\(line)")
		let task = Task {
			// Espera activa corta para evitar bloquear el test innecesariamente si la request llega rápido
			for _ in 0..<100 { // Intentar hasta 1 segundo (100 * 10ms)
				if !httpClient.requests.isEmpty {
					expectation.fulfill()
					return
				}
				try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
			}
		}
		
		await fulfillment(of: [expectation], timeout: timeout)
		task.cancel() // Cancelar la tarea de espera si se cumple por timeout o se completa
		
		if httpClient.requests.isEmpty {
			XCTFail("HTTPClientSpy never received a request within timeout", file: file, line: line)
		}
	}
	
	private func makeSUT(
		file: StaticString = #file, line: UInt = #line
		// El tipo de retorno httpClient puede ser HTTPClientSpy o un tipo más específico si lo tienes.
		// Ajusta RegistrationHTTPClientSpy a HTTPClientSpy si ese es el tipo real de httpClient.
	) -> (sut: UserRegistrationUseCase, httpClient: HTTPClientSpy) { // Asumiendo httpClient es HTTPClientSpy
		let httpClient = HTTPClientSpy() // O RegistrationHTTPClientSpy() si es un spy más específico
		
		
		let tokenStorage = TokenStorageSpy()
		
		let sut = UserRegistrationUseCase(
			keychain: makeKeychainFullSpy(), // Asume que este helper es correcto
			tokenStorage: tokenStorage,
			validator: RegistrationValidatorStub(), // O RegistrationValidatorAlwaysValid() si es más apropiado para el uso de este SUT
			httpClient: httpClient,
			registrationEndpoint: URL(string: "https://test-register-endpoint.com")!,
			notifier: nil // Asumimos que el notifier es opcional en el init y puede ser nil aquí.
			// Si el init requiere notifier, necesitarás pasar UserRegistrationNotifierSpy().
		)
		
		
		trackForMemoryLeaks(httpClient, file: file, line: line)
		trackForMemoryLeaks(sut, file: file, line: line)
		
		trackForMemoryLeaks(tokenStorage, file: file, line: line)
		
		return (sut, httpClient)
	}
	
}
