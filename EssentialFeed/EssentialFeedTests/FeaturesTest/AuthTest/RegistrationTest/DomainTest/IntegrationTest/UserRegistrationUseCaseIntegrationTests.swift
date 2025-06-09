import EssentialFeed
import XCTest

class UserRegistrationUseCaseIntegrationTests: XCTestCase {
    func test_register_withSuccessfulServerResponse_savesTokenAndCredentials() async throws {
        let uniqueUser = UserRegistrationData.makeUnique()
        let expectedToken = Token.make()
        let serverResponseData = try makeServerResponseData(for: uniqueUser, token: expectedToken)

        let httpClientStub = HTTPClientStub.online { _ in
            (
                serverResponseData,
                HTTPURLResponse(url: anyURL(), statusCode: 201, httpVersion: nil, headerFields: nil)!
            )
        }

        let persistenceSpy = IntegrationPersistenceSpy()
        let notifierSpy = UserRegistrationNotifierSpy()

        let (sut, _) = makeSUT(
            httpClient: httpClientStub,
            persistenceSpy: persistenceSpy,
            notifierSpy: notifierSpy
        )

        let result = await sut.register(
            name: uniqueUser.name,
            email: uniqueUser.email,
            password: uniqueUser.password
        )

        switch result {
        case let .success(tokenAndUser):
            XCTAssertEqual(tokenAndUser.user.name, uniqueUser.name)
            XCTAssertEqual(tokenAndUser.user.email, uniqueUser.email)

            XCTAssertEqual(persistenceSpy.tokenStorageMessages.count, 1)
            if case let .save(tokenBundle: savedToken) = persistenceSpy.tokenStorageMessages.first {
                XCTAssertEqual(savedToken.accessToken, expectedToken.accessToken)
                XCTAssertEqual(savedToken.expiry.timeIntervalSince1970, expectedToken.expiry.timeIntervalSince1970, accuracy: 1.0)
                XCTAssertNil(savedToken.refreshToken)
                XCTAssertNil(expectedToken.refreshToken)
            } else {
                XCTFail("Expected token to be saved with correct message, got \(String(describing: persistenceSpy.tokenStorageMessages.first))")
            }

            XCTAssertEqual(persistenceSpy.keychainSaveDataCalls.count, 1)
            XCTAssertEqual(persistenceSpy.keychainSaveDataCalls.first?.key, uniqueUser.email)
            XCTAssertEqual(persistenceSpy.keychainSaveDataCalls.first?.data, uniqueUser.password.data(using: .utf8))
            XCTAssertTrue(persistenceSpy.offlineStoreSaveCalls.isEmpty)
            XCTAssertTrue(notifierSpy.receivedErrors.isEmpty)

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

        let (sut, _) = makeSUT(
            httpClient: httpClientStub,
            persistenceSpy: persistenceSpy,
            notifierSpy: notifierSpy
        )

        let result = await sut.register(
            name: uniqueUser.name,
            email: uniqueUser.email,
            password: uniqueUser.password
        )

        switch result {
        case .success:
            XCTFail("Expected connectivity failure, but got success instead.")

        case let .failure(error):
            XCTAssertEqual(error as? NetworkError, .noConnectivity, "The returned error should be .noConnectivity")

            XCTAssertEqual(persistenceSpy.offlineStoreSaveCalls.count, 1)
            if let savedData = persistenceSpy.offlineStoreSaveCalls.first {
                let expectedDataToSave = UserRegistrationData(
                    name: uniqueUser.name, email: uniqueUser.email, password: uniqueUser.password
                )
                XCTAssertEqual(savedData, expectedDataToSave)
            } else {
                XCTFail("Expected offline store to save registration data")
            }

            XCTAssertEqual(notifierSpy.receivedErrors.count, 1, "UserRegistrationNotifierSpy should have been notified once")
            XCTAssertEqual(notifierSpy.receivedErrors.first as? NetworkError, .noConnectivity, "The notifier should be notified with the .noConnectivity error")

            XCTAssertTrue(persistenceSpy.tokenStorageMessages.isEmpty, "TokenStorage should not have any interactions on connectivity failure")
            XCTAssertEqual(persistenceSpy.keychainSaveDataCalls.count, 0)
        }
    }

    // TODO: Consider adding integration tests for other server errors (409, 500) if needed, although the unit tests already cover them well.

    // MARK: - Helpers

    private func makeSUT(
        httpClient: HTTPClientStub,
        persistenceSpy: IntegrationPersistenceSpy,
        notifierSpy: UserRegistrationNotifierSpy,
        file: StaticString = #file,
        line: UInt = #line
    ) -> (sut: UserRegistrationUseCase, validator: RegistrationValidatorAlwaysValid) {
        let validator = RegistrationValidatorAlwaysValid()
        let replayProtector = ReplayAttackProtectorSpy()
        let responseMapper = UserRegistrationResponseMapper(notifier: notifierSpy)
        let registrationPersistenceService = DefaultRegistrationPersistenceService(tokenStorage: persistenceSpy, credentialsStore: persistenceSpy, offlineStore: persistenceSpy)
        let offlineHandler = DefaultOfflineRegistrationHandler(offlineStore: persistenceSpy, notifier: notifierSpy)

        let commands: [RegistrationCommand] = [
            ValidationCommand(validator: validator, notifier: notifierSpy),
            RequestCreationCommand(registrationEndpoint: anyURL()),
            ReplayProtectionCommand(replayProtector: replayProtector),
            HTTPRequestCommand(httpClient: httpClient),
            ResponseMappingCommand(responseMapper: responseMapper),
            PersistenceCommand(persistenceService: registrationPersistenceService)
        ]

        let registrationService = RegistrationCommandChain(commands: commands, offlineHandler: offlineHandler, notifier: notifierSpy)
        let sut = UserRegistrationUseCase(registrationService: registrationService)

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(httpClient, file: file, line: line)
        trackForMemoryLeaks(persistenceSpy, file: file, line: line)
        trackForMemoryLeaks(notifierSpy, file: file, line: line)
        trackForMemoryLeaks(validator, file: file, line: line)

        return (sut, validator)
    }

    private func makeServerResponseData(for userData: UserRegistrationData, token: Token) throws -> Data {
        let userPayload = ServerAuthResponse.UserPayload(name: userData.name, email: userData.email)
        let tokenPayload = ServerAuthResponse.TokenPayload(
            value: token.accessToken, expiry: token.expiry
        )
        let serverResponsePayload = ServerAuthResponse(user: userPayload, token: tokenPayload)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(serverResponsePayload)
    }
}

private extension UserRegistrationData {
    static func makeUnique(id: UUID = UUID()) -> UserRegistrationData {
        UserRegistrationData(
            name: "User \(id.uuidString.prefix(8))", email: "user-\(id.uuidString.prefix(8))@example.com",
            password: "Password\(id.uuidString.prefix(8))"
        )
    }
}

private extension Token {
    static func make(
        accessToken: String = "test-token-\(UUID().uuidString)",
        expiryInterval: TimeInterval = 3600,
        refreshToken: String? = nil
    ) -> Token {
        Token(
            accessToken: accessToken, expiry: Date().addingTimeInterval(expiryInterval),
            refreshToken: refreshToken
        )
    }
}
