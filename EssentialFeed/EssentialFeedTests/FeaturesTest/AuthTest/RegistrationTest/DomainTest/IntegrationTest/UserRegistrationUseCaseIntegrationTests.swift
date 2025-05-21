import EssentialFeed
import XCTest

class UserRegistrationUseCaseIntegrationTests: XCTestCase {
    func test_register_withSuccessfulServerResponse_savesTokenAndCredentials() async throws {
        let uniqueUser = UserRegistrationData.makeUnique()
        let expectedToken = Token.make()
        let userPayload = ServerAuthResponse.UserPayload(name: uniqueUser.name, email: uniqueUser.email)
        let tokenPayload = ServerAuthResponse.TokenPayload(value: expectedToken.accessToken, expiry: expectedToken.expiry)
        let serverResponsePayload = ServerAuthResponse(user: userPayload, token: tokenPayload)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let serverResponseData = try encoder.encode(serverResponsePayload)

        let httpClientStub = HTTPClientStub.online { _ in
            (serverResponseData, HTTPURLResponse(url: anyURL(), statusCode: 201, httpVersion: nil, headerFields: nil)!)
        }

        let persistenceSpy = IntegrationPersistenceSpy()
        let notifierSpy = UserRegistrationNotifierSpy()
        let validator = RegistrationValidatorAlwaysValid()

        let sut = UserRegistrationUseCase(
            persistenceService: persistenceSpy,
            validator: validator,
            httpClient: httpClientStub,
            registrationEndpoint: anyURL(),
            notifier: notifierSpy
        )

        trackForMemoryLeaks(sut, file: #file, line: #line)
        trackForMemoryLeaks(httpClientStub, file: #file, line: #line)
        trackForMemoryLeaks(persistenceSpy, file: #file, line: #line)
        trackForMemoryLeaks(notifierSpy, file: #file, line: #line)

        let result = await sut.register(
            name: uniqueUser.name,
            email: uniqueUser.email,
            password: uniqueUser.password
        )

        switch result {
        case let .success(registeredUser):
            XCTAssertEqual(registeredUser.name, uniqueUser.name)
            XCTAssertEqual(registeredUser.email, uniqueUser.email)

            XCTAssertEqual(persistenceSpy.tokenStorageMessages.count, 1)
            if case let .save(tokenBundle: savedToken) = persistenceSpy.tokenStorageMessages.first {
                XCTAssertEqual(savedToken.accessToken, expectedToken.accessToken)
                XCTAssertEqual(savedToken.expiry.timeIntervalSince1970, expectedToken.expiry.timeIntervalSince1970, accuracy: 1.0)
                XCTAssertNil(savedToken.refreshToken)
                XCTAssertNil(expectedToken.refreshToken)
            } else {
                XCTFail("Expected token to be saved with correct message, got \(String(describing: persistenceSpy.tokenStorageMessages.first))")
            }

            XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.count, 1)
            XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.first?.key, uniqueUser.email)
            XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.first?.data, uniqueUser.password.data(using: .utf8))

            XCTAssertTrue(persistenceSpy.offlineStoreMessages.isEmpty)
            XCTAssertTrue(notifierSpy.receivedErrors.isEmpty, "Expected no errors to be notified on success")

        case let .failure(error):
            XCTFail("Expected successful registration, got \(error) instead")
        }
    }

    func test_register_withNoConnectivity_savesToOfflineStore_andNotifies() async throws {
        let uniqueUser = UserRegistrationData.makeUnique()
        let connectivityError = NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue)

        let httpClientStub = HTTPClientStub.stubForError(connectivityError)

        let persistenceSpy = IntegrationPersistenceSpy()
        let notifierSpy = UserRegistrationNotifierSpy()
        let validator = RegistrationValidatorAlwaysValid()

        let sut = UserRegistrationUseCase(
            persistenceService: persistenceSpy,
            validator: validator,
            httpClient: httpClientStub,
            registrationEndpoint: anyURL(),
            notifier: notifierSpy
        )

        trackForMemoryLeaks(sut, file: #file, line: #line)
        trackForMemoryLeaks(httpClientStub, file: #file, line: #line)
        trackForMemoryLeaks(persistenceSpy, file: #file, line: #line)
        trackForMemoryLeaks(notifierSpy, file: #file, line: #line)
        trackForMemoryLeaks(validator, file: #file, line: #line)

        let result = await sut.register(
            name: uniqueUser.name,
            email: uniqueUser.email,
            password: uniqueUser.password
        )

        switch result {
        case .success:
            XCTFail("Se esperaba un fallo por conectividad, pero se obtuvo éxito.")

        case let .failure(error):
            XCTAssertEqual(error as? NetworkError, .noConnectivity, "El error devuelto debe ser .noConnectivity")

            XCTAssertEqual(persistenceSpy.offlineStoreMessages.count, 1, "OfflineRegistrationStoreSpy debe intentar guardar los datos una vez")
            if case let .save(savedData) = persistenceSpy.offlineStoreMessages.first {
                let expectedDataToSave = UserRegistrationData(name: uniqueUser.name, email: uniqueUser.email, password: uniqueUser.password)
                XCTAssertEqual(savedData, expectedDataToSave, "Los datos guardados en offline store no coinciden")
            } else {
                XCTFail("Se esperaba un mensaje .save en OfflineRegistrationStoreSpy, se obtuvo \(String(describing: persistenceSpy.offlineStoreMessages.first))")
            }

            XCTAssertEqual(notifierSpy.receivedErrors.count, 1, "UserRegistrationNotifierSpy debe haber sido notificado una vez")
            XCTAssertEqual(notifierSpy.receivedErrors.first as? NetworkError, .noConnectivity, "El notifier debe ser notificado con el error .noConnectivity")

            XCTAssertTrue(persistenceSpy.tokenStorageMessages.isEmpty, "TokenStorage no debería tener interacciones en fallo de conectividad")
            XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.count, 0, "Keychain no debería guardar nada en fallo de conectividad")
        }
    }

    // TODO: Considerar añadir tests de integración para otros errores de servidor (409, 500) si se ve necesario, aunque los unit tests ya los cubren bien.
}

private extension UserRegistrationData {
    static func makeUnique(id: UUID = UUID()) -> UserRegistrationData {
        UserRegistrationData(name: "User \(id.uuidString.prefix(8))", email: "user-\(id.uuidString.prefix(8))@example.com", password: "Password\(id.uuidString.prefix(8))")
    }
}

private extension Token {
    static func make(
        accessToken: String = "test-token-\(UUID().uuidString)",
        expiryInterval: TimeInterval = 3600,
        refreshToken: String? = nil
    ) -> Token {
        Token(accessToken: accessToken, expiry: Date().addingTimeInterval(expiryInterval), refreshToken: refreshToken)
    }
}
