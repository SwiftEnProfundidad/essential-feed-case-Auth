import XCTest
import EssentialFeed

class UserRegistrationUseCaseIntegrationTests: XCTestCase {
	
	func test_register_withSuccessfulServerResponse_savesTokenAndCredentials() async throws {
		// Arrange
		let uniqueUser = UserRegistrationData.makeUnique()
		let expectedToken = Token.make()
		
		let serverResponsePayload = ServerAuthResponse(
			user: .init(name: uniqueUser.name, email: uniqueUser.email),
			token: .init(value: expectedToken.value, expiry: expectedToken.expiry)
		)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		let serverResponseData = try encoder.encode(serverResponsePayload)
		
		let httpClientStub = HTTPClientStub.online { _ in
			(serverResponseData, HTTPURLResponse(url: anyURL(), statusCode: 201, httpVersion: nil, headerFields: nil)!)
		}
		
		let tokenStorageSpy = TokenStorageSpy()
		let keychainSpy = KeychainFullSpy()
		let offlineStoreSpy = OfflineRegistrationStoreSpy()
		let notifierSpy = UserRegistrationNotifierSpy()
		let validator = RegistrationValidatorAlwaysValid()
		
		let sut = UserRegistrationUseCase(
			keychain: keychainSpy,
			tokenStorage: tokenStorageSpy,
			offlineStore: offlineStoreSpy,
			validator: validator,
			httpClient: httpClientStub,
			registrationEndpoint: anyURL(),
			notifier: notifierSpy
		)
		
		trackForMemoryLeaks(sut, file: #file, line: #line)
		trackForMemoryLeaks(httpClientStub, file: #file, line: #line)
		trackForMemoryLeaks(tokenStorageSpy, file: #file, line: #line)
		trackForMemoryLeaks(keychainSpy, file: #file, line: #line)
		trackForMemoryLeaks(offlineStoreSpy, file: #file, line: #line)
		trackForMemoryLeaks(notifierSpy, file: #file, line: #line)
		
		// Act
		let result = await sut.register(
			name: uniqueUser.name,
			email: uniqueUser.email,
			password: uniqueUser.password
		)
		
		// Assert
		switch result {
			case .success(let registeredUser):
				XCTAssertEqual(registeredUser.name, uniqueUser.name)
				XCTAssertEqual(registeredUser.email, uniqueUser.email)
				
				XCTAssertEqual(tokenStorageSpy.messages.count, 1)
				if case let .save(savedToken) = tokenStorageSpy.messages.first {
					XCTAssertEqual(savedToken.value, expectedToken.value)
					XCTAssertEqual(savedToken.expiry.timeIntervalSince1970, expectedToken.expiry.timeIntervalSince1970, accuracy: 1.0)
				} else {
					XCTFail("Expected token to be saved, got \(String(describing: tokenStorageSpy.messages.first))")
				}
				
				XCTAssertEqual(keychainSpy.saveSpy.saveCallCount, 1)
				XCTAssertEqual(keychainSpy.saveSpy.lastKey, uniqueUser.email)
				XCTAssertEqual(keychainSpy.saveSpy.lastData, uniqueUser.password.data(using: .utf8))
				
				XCTAssertTrue(offlineStoreSpy.messages.isEmpty)
				XCTAssertTrue(notifierSpy.receivedErrors.isEmpty, "Expected no errors to be notified on success")
				
			case .failure(let error):
				XCTFail("Expected successful registration, got \(error) instead")
		}
	}
	
	func test_register_withNoConnectivity_savesToOfflineStore_andNotifies() async throws {
		// Arrange
		let uniqueUser = UserRegistrationData.makeUnique()
		let connectivityError = NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue)
		
		let httpClientStub = HTTPClientStub.stubForError(connectivityError)
		
		let tokenStorageSpy = TokenStorageSpy()
		let keychainSpy = KeychainFullSpy() 
		let offlineStoreSpy = OfflineRegistrationStoreSpy() 
		let notifierSpy = UserRegistrationNotifierSpy()     
		let validator = RegistrationValidatorAlwaysValid()  
		
		let sut = UserRegistrationUseCase(
			keychain: keychainSpy,
			tokenStorage: tokenStorageSpy,
			offlineStore: offlineStoreSpy,
			validator: validator,
			httpClient: httpClientStub,
			registrationEndpoint: anyURL(), 
			notifier: notifierSpy
		)
		
		trackForMemoryLeaks(sut, file: #file, line: #line)
		trackForMemoryLeaks(httpClientStub, file: #file, line: #line)
		trackForMemoryLeaks(tokenStorageSpy, file: #file, line: #line)
		trackForMemoryLeaks(keychainSpy, file: #file, line: #line)
		trackForMemoryLeaks(offlineStoreSpy, file: #file, line: #line)
		trackForMemoryLeaks(notifierSpy, file: #file, line: #line)
		trackForMemoryLeaks(validator, file: #file, line: #line) 
		
		// Act
		let result = await sut.register(
			name: uniqueUser.name, 
			email: uniqueUser.email, 
			password: uniqueUser.password
		)
		
		// Assert
		switch result {
			case .success:
				XCTFail("Se esperaba un fallo por conectividad, pero se obtuvo éxito.")
				
			case .failure(let error):
				XCTAssertEqual(error as? NetworkError, .noConnectivity, "El error devuelto debe ser .noConnectivity")
				
				XCTAssertEqual(offlineStoreSpy.messages.count, 1, "OfflineRegistrationStoreSpy debe intentar guardar los datos una vez")
				if case let .save(savedData) = offlineStoreSpy.messages.first {
					let expectedDataToSave = UserRegistrationData(name: uniqueUser.name, email: uniqueUser.email, password: uniqueUser.password)
					XCTAssertEqual(savedData, expectedDataToSave, "Los datos guardados en offline store no coinciden")
				} else {
					XCTFail("Se esperaba un mensaje .save en OfflineRegistrationStoreSpy, se obtuvo \(String(describing: offlineStoreSpy.messages.first))")
				}
				
				XCTAssertEqual(notifierSpy.receivedErrors.count, 1, "UserRegistrationNotifierSpy debe haber sido notificado una vez")
				XCTAssertEqual(notifierSpy.receivedErrors.first as? NetworkError, .noConnectivity, "El notifier debe ser notificado con el error .noConnectivity")
				
				XCTAssertTrue(tokenStorageSpy.messages.isEmpty, "TokenStorage no debería tener interacciones en fallo de conectividad")
				XCTAssertEqual(keychainSpy.saveSpy.saveCallCount, 0, "Keychain no debería guardar nada en fallo de conectividad")
		}
	}
	
	// TODO: Considerar añadir tests de integración para otros errores de servidor (409, 500) si se ve necesario,
	// aunque los unit tests ya los cubren bien.
}

// MARK: - Helpers Comunes

private struct ServerAuthResponse: Codable {
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

private extension UserRegistrationData {
	static func makeUnique(id: UUID = UUID()) -> UserRegistrationData {
		UserRegistrationData(name: "User \(id.uuidString.prefix(8))", email: "user-\(id.uuidString.prefix(8))@example.com", password: "Password\(id.uuidString.prefix(8))")
	}
}

private extension Token {
	static func make(value: String = "test-token-\(UUID().uuidString)", expiryInterval: TimeInterval = 3600) -> Token {
		Token(value: value, expiry: Date().addingTimeInterval(expiryInterval))
	}
}

extension HTTPClientStub {
	static func stubForError(_ error: Error) -> HTTPClientStub {
		HTTPClientStub { _ in .failure(error) }
	}
}
