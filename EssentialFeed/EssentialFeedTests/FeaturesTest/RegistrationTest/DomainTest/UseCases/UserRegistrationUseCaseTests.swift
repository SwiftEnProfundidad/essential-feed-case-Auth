

// Al principio de UserRegistrationUseCaseTests.swift, asegúrate de importar EssentialFeed si no está ya.
// import EssentialFeed

// ... (código existente de la clase y otros tests) ...

	private func makeSUTWithDefaults(
		httpClient: HTTPClient = HTTPClientSpy(), // Asumo que HTTPClientSpy está definido o accesible
		tokenStorage: TokenStorage = TokenStorageSpy(), // Asumo que TokenStorageSpy está definido o accesible
		offlineStore: OfflineRegistrationStore = OfflineRegistrationStoreSpy(), // Asumo que OfflineRegistrationStoreSpy está definido o accesible
		notifier: UserRegistrationNotifier = UserRegistrationNotifierSpy(), // Asumo que UserRegistrationNotifierSpy está definido o accesible
		name: String = "Test User",
		email: String = "test@email.com",
		password: String = "Password123",
		file: StaticString = #file, line: UInt = #line
	) -> (sut: UserRegistrationUseCase, keychain: KeychainFullSpy, name: String, email: String, password: String, notifier: UserRegistrationNotifier, tokenStorage: TokenStorageSpy, offlineStore: OfflineRegistrationStoreSpy) {
		let keychain = KeychainFullSpy() // Asumo que KeychainFullSpy está definido o accesible
		let registrationEndpoint = anyURL() // Asumo que anyURL() está definido o accesible
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			tokenStorage: tokenStorage,
			offlineStore: offlineStore,
            // CHANGE: Usar RegistrationValidatorAlwaysValid para los defaults donde no se espera fallo de validación
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
        // Asegúrate de que el notifier spy también se rastree si es una clase
        if let notifierSpy = notifier as? UserRegistrationNotifierSpy {
             trackForMemoryLeaks(notifierSpy, file: file, line: line)
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
		let httpClient = HTTPClientDummy() // Asumo que HTTPClientDummy está definido o accesible
		let registrationEndpoint = URL(string: "https://test-register-endpoint.com")!
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			tokenStorage: tokenStorage,
			offlineStore: offlineStore,
            // CHANGE: Usar RegistrationValidatorAlwaysValid si no se prueban fallos de validación aquí
			validator: RegistrationValidatorAlwaysValid(), 
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
		// ... (prints de depuración si los quieres mantener) ...
		
		let keychain = makeKeychainFullSpy()
        // CHANGE: Usar RegistrationValidatorTestStub, que tiene errorToReturn
		let validator = RegistrationValidatorTestStub() 
		validator.errorToReturn = expectedError
		
		let httpClient = HTTPClientSpy()
		let tokenStorage = TokenStorageSpy()
		
		// ... (print de depuración) ...
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			tokenStorage: tokenStorage,
			offlineStore: offlineStore,
			validator: validator, 
			httpClient: httpClient,
			registrationEndpoint: anyURL()
		)
		
		if let offlineStoreSpy = offlineStore as? OfflineRegistrationStoreSpy {
			trackForMemoryLeaks(offlineStoreSpy, file: file, line: line)
		}
		// trackForMemoryLeaks(validator as AnyObject) // RegistrationValidatorTestStub es una clase
        trackForMemoryLeaks(validator, file: file, line: line)
		trackForMemoryLeaks(keychain, file: file, line: line)
		trackForMemoryLeaks(httpClient, file: file, line: line)
		trackForMemoryLeaks(tokenStorage, file: file, line: line)
		trackForMemoryLeaks(sut, file: file, line: line)
		
		// ... (prints y lógica del test como estaba) ...
		let result = await sut.register(name: name, email: email, password: password)
		
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
		// ... (prints de depuración si los quieres mantener) ...
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
            // CHANGE: Decide si aquí necesitas un stub configurable o uno que siempre pase.
            // Si los tests que usan este makeSUT no prueban fallos de validación, RegistrationValidatorAlwaysValid() es más simple.
            // Si sí prueban fallos de validación, entonces RegistrationValidatorTestStub().
            // Por ahora, lo dejo como RegistrationValidatorAlwaysValid() para ser consistente.
			validator: RegistrationValidatorAlwaysValid(), 
			httpClient: httpClient,
			registrationEndpoint: URL(string: "https://test-register-endpoint.com")!,
			notifier: nil // Asumo que para este makeSUT simple no se prueba el notifier
		)
		if let offlineStoreSpy = offlineStore as? OfflineRegistrationStoreSpy {
			trackForMemoryLeaks(offlineStoreSpy, file: file, line: line)
		}
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(httpClient, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)
		return (sut, httpClient)
	}

// ... (resto del archivo: definiciones de spies/stubs locales si aún quedan, o se eliminan si están centralizadas) ...
// Asumo que OfflineRegistrationStoreSpy, UserRegistrationNotifierSpy, HTTPClientSpy, TokenStorageSpy, KeychainFullSpy
// y anyURL() ahora provienen de tus archivos de Helpers centralizados.

// Asegúrate de que las clases RegistrationValidatorTestStub y RegistrationValidatorAlwaysValid
// estén definidas en tus helpers (ej. en RegistrationValidatorTestHelpers.swift) y sean accesibles aquí.

