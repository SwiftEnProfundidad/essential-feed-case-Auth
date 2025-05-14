
import EssentialFeed
import Security
import XCTest

final class UserRegistrationUseCaseTests: XCTestCase {
    func test_registerUser_withValidDataAndToken_createsUserStoresCredentialsAndToken() async throws {
        let httpClient = HTTPClientSpy()
        let persistenceSpy = RegistrationPersistenceSpy()
        let url = anyURL()
        let response201 = HTTPURLResponse(
            url: url,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )!
        let (sut, name, email, password, _, returnedPersistenceSpy) = makeSUTWithDefaults(httpClient: httpClient, persistence: persistenceSpy)
        let expectedTokenToReceiveAndStore = makeToken()
        let serverResponseData = try makeRegistrationServerResponseData(name: name, email: email, token: expectedTokenToReceiveAndStore)

        let registerTask = Task {
            await sut.register(name: name, email: email, password: password)
        }

        await expectHTTPRequest(from: httpClient)
        httpClient.complete(with: serverResponseData, response: response201)
        let result = await registerTask.value

        switch result {
        case let .success(user):
            XCTAssertEqual(user.name, name, "Registered user's name should match input")
            XCTAssertEqual(user.email, email, "Registered user's email should match input")

            XCTAssertEqual(returnedPersistenceSpy.saveKeychainDataCalls.count, 1, "Expected to save credentials once")
            XCTAssertEqual(returnedPersistenceSpy.saveKeychainDataCalls.first?.key, email, "Expected to save credentials for the correct email")
            XCTAssertEqual(returnedPersistenceSpy.saveKeychainDataCalls.first?.data, password.data(using: .utf8), "Expected to save correct password data")

            XCTAssertEqual(returnedPersistenceSpy.tokenStorageMessages.count, 1, "Expected to save token once")
            if case let .save(savedToken) = returnedPersistenceSpy.tokenStorageMessages.first {
                XCTAssertEqual(savedToken, expectedTokenToReceiveAndStore, "Expected to save the correct token received from server")
            } else {
                XCTFail("Expected save message in TokenStorageMessages, got \(String(describing: returnedPersistenceSpy.tokenStorageMessages.first))")
            }
        case let .failure(error):
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
        let persistenceSpy = RegistrationPersistenceSpy()
        let url = anyURL()
        let response201 = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
        let (sut, name, email, password, _, returnedPersistenceSpy) = makeSUTWithDefaults(httpClient: httpClient, persistence: persistenceSpy)

        let tokenFromServer = makeToken()
        let serverResponseData = try makeRegistrationServerResponseData(name: name, email: email, token: tokenFromServer)

        let tokenStorageError = NSError(domain: "TokenStorageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to save token"])
        returnedPersistenceSpy.saveTokenError = tokenStorageError

        let registerTask = Task {
            await sut.register(name: name, email: email, password: password)
        }

        await expectHTTPRequest(from: httpClient)
        httpClient.complete(with: serverResponseData, response: response201)
        let result = await registerTask.value

        switch result {
        case .success:
            XCTFail("Expected failure due to token storage error, got success instead")
        case let .failure(error):
            XCTAssertEqual(error as NSError, tokenStorageError, "Expected token storage error")
        }
        XCTAssertEqual(returnedPersistenceSpy.saveKeychainDataCalls.count, 0, "Keychain save should not be called if token storage fails")
        XCTAssertEqual(returnedPersistenceSpy.tokenStorageMessages.count, 1, "Expected TokenStorage save to be attempted once")
        if case let .save(attemptedToken) = returnedPersistenceSpy.tokenStorageMessages.first {
            XCTAssertEqual(attemptedToken, tokenFromServer, "Expected to attempt saving the correct token")
        } else {
            XCTFail("Expected save message in TokenStorageMessages, got \(String(describing: returnedPersistenceSpy.tokenStorageMessages.first))")
        }
    }

    func test_registerUser_withValidData_whenServerResponseIsMissingOrMalformedToken_returnsError() async throws {
        let httpClient = HTTPClientSpy()
        let persistenceSpy = RegistrationPersistenceSpy()
        let url = anyURL()
        let response201 = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
        let (sut, name, email, password, _, returnedPersistenceSpy) = makeSUTWithDefaults(httpClient: httpClient, persistence: persistenceSpy)

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
        case let .failure(error):
            XCTAssertTrue(error is DecodingError || error is TokenParsingError, "Expected a parsing error or TokenParsingError")
        }
        XCTAssertEqual(returnedPersistenceSpy.saveKeychainDataCalls.count, 0, "Keychain save should not be called if token parsing fails")
        XCTAssertEqual(returnedPersistenceSpy.tokenStorageMessages.count, 0, "TokenStorage save should not be attempted if token parsing fails")
    }

    func test_registerUser_withAlreadyRegisteredEmail_notifiesEmailAlreadyInUsePresenter() async {
        let httpClient = HTTPClientSpy()
        let notifierExpectation = expectation(description: "Notifier should be called for email in use")

        let (sut, name, email, password, notifierSpy, returnedPersistenceSpy) = makeSUTWithDefaults(
            httpClient: httpClient,
            persistence: RegistrationPersistenceSpy(),
            notifier: UserRegistrationNotifierSpy(onNotify: { notifierExpectation.fulfill() })
        )

        let registerTask = Task {
            await sut.register(name: name, email: email, password: password)
        }

        await expectHTTPRequest(from: httpClient)

        let response409 = HTTPURLResponse(url: httpClient.requests.first?.url ?? anyURL(), statusCode: 409, httpVersion: nil, headerFields: nil)!
        httpClient.complete(with: Data(), response: response409)

        let result = await registerTask.value

        await fulfillment(of: [notifierExpectation], timeout: 1.0)

        XCTAssertTrue(notifierSpy.notifiedEmailInUse, "Notifier should be called with emailAlreadyInUse error")
        XCTAssertEqual(returnedPersistenceSpy.saveKeychainDataCalls.count, 0, "Keychain save should not be called on registration failure")
        switch result {
        case let .failure(errorReceived):
            guard let registrationError = errorReceived as? UserRegistrationError else {
                XCTFail("Expected UserRegistrationError, got \(errorReceived) instead")
                return
            }
            XCTAssertEqual(registrationError, .emailAlreadyInUse, "Expected .emailAlreadyInUse error")
        default:
            XCTFail("Expected .emailAlreadyInUse error, got \(result) instead")
        }
    }

    func test_registerUser_withAlreadyRegisteredEmail_returnsEmailAlreadyInUseError_andDoesNotStoreCredentials() async {
        let httpClient = HTTPClientSpy()
        let (sut, name, email, password, _, returnedPersistenceSpy) = makeSUTWithDefaults(httpClient: httpClient, persistence: RegistrationPersistenceSpy())

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
        case let .failure(error as UserRegistrationError):
            XCTAssertEqual(error, .emailAlreadyInUse, "Expected .emailAlreadyInUse error")
        default:
            XCTFail("Expected .emailAlreadyInUse error, got \(result) instead")
        }
        XCTAssertEqual(returnedPersistenceSpy.saveKeychainDataCalls.count, 0, "No Keychain save should occur if email is already registered")
    }

    func test_registerUser_withNoConnectivity_returnsConnectivityError_andDoesNotStoreCredentials() async {
        let httpClient = HTTPClientSpy()
        let (sut, name, email, password, _, returnedPersistenceSpy) = makeSUTWithDefaults(httpClient: httpClient, persistence: RegistrationPersistenceSpy())
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

        XCTAssertEqual(returnedPersistenceSpy.saveKeychainDataCalls.count, 0, "No Keychain save should occur if there is no connectivity")
        XCTAssertTrue(returnedPersistenceSpy.tokenStorageMessages.isEmpty, "No TokenStorage save should occur if there is no connectivity")
    }

    func test_register_whenNoConnectivity_savesDataToOfflineStoreAndReturnsConnectivityError() async throws {
        let httpClient = HTTPClientSpy()
        let (sut, name, email, password, notifier, returnedPersistenceSpy) = makeSUTWithDefaults(httpClient: httpClient, persistence: RegistrationPersistenceSpy())
        let expectedUserData = UserRegistrationData(name: name, email: email, password: password)

        let registerTask = Task {
            let res = await sut.register(name: name, email: email, password: password)
            return res
        }

        await expectHTTPRequest(from: httpClient)
        httpClient.complete(with: NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue))

        let result = await registerTask.value

        XCTAssertEqual(returnedPersistenceSpy.offlineStoreMessages.count, 1, "Expected to save data once to offline store")
        if let firstMessage = returnedPersistenceSpy.offlineStoreMessages.first {
            switch firstMessage {
            case let .save(savedData):
                XCTAssertEqual(savedData, expectedUserData, "Expected to save correct user data to offline store")
            }
        } else {
            XCTFail("Expected .save message in offlineStoreMessages, but messages array is empty.")
        }

        switch result {
        case let .failure(error as NetworkError):
            XCTAssertEqual(error, .noConnectivity, "Expected noConnectivity error")
        default:
            XCTFail("Expected noConnectivity error, got \(String(describing: result)) instead")
        }

        XCTAssertTrue(notifier.notifiedConnectivityError, "Notifier should be called with noConnectivity error")
        XCTAssertEqual(returnedPersistenceSpy.saveKeychainDataCalls.count, 0, "Keychain save should not be called on connectivity error")
        XCTAssertTrue(returnedPersistenceSpy.tokenStorageMessages.isEmpty, "TokenStorage save should not be called on connectivity error")
    }

    // MARK: - Helpers

    private func makeSUTWithDefaults(
        httpClient: HTTPClientSpy = HTTPClientSpy(),
        persistence: RegistrationPersistenceSpy = RegistrationPersistenceSpy(),
        notifier: UserRegistrationNotifierSpy = UserRegistrationNotifierSpy(),
        name: String = "Test User",
        email: String = "test@email.com",
        password: String = "Password123",
        file: StaticString = #file, line: UInt = #line
    ) -> (sut: UserRegistrationUseCase, name: String, email: String, password: String, notifier: UserRegistrationNotifierSpy, persistence: RegistrationPersistenceSpy) {
        let registrationEndpoint = anyURL()
        let sut = UserRegistrationUseCase(
            persistence: persistence,
            validator: RegistrationValidatorAlwaysValid(),
            httpClient: httpClient,
            registrationEndpoint: registrationEndpoint,
            notifier: notifier
        )
        trackForMemoryLeaks(persistence, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(httpClient, file: file, line: line)

        trackForMemoryLeaks(notifier, file: file, line: line)

        return (sut, name, email, password, notifier, persistence)
    }

    private func makeSUT(
        persistence: RegistrationPersistenceSpy = RegistrationPersistenceSpy(),
        file: StaticString = #file, line: UInt = #line
    ) -> (sut: UserRegistrationUseCase, httpClient: HTTPClientSpy, persistence: RegistrationPersistenceSpy) {
        let httpClient = HTTPClientSpy()

        let sut = UserRegistrationUseCase(
            persistence: persistence,
            validator: RegistrationValidatorAlwaysValid(),
            httpClient: httpClient,
            registrationEndpoint: URL(string: "https://test-register-endpoint.com")!,
            notifier: nil
        )
        trackForMemoryLeaks(persistence, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(httpClient, file: file, line: line)
        return (sut, httpClient, persistence)
    }

    private func assertRegistrationValidation(
        name: String,
        email: String,
        password: String,
        expectedError: RegistrationValidationError,
        persistence: RegistrationPersistenceSpy = RegistrationPersistenceSpy(),
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let validator = RegistrationValidatorTestStub()
        validator.errorToReturn = expectedError
        let httpClient = HTTPClientSpy()

        let sut = UserRegistrationUseCase(
            persistence: persistence,
            validator: validator,
            httpClient: httpClient,
            registrationEndpoint: anyURL()
        )

        trackForMemoryLeaks(persistence, file: file, line: line)
        trackForMemoryLeaks(validator, file: file, line: line)
        trackForMemoryLeaks(httpClient, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        let result = await sut.register(name: name, email: email, password: password)

        switch result {
        case let .failure(error as RegistrationValidationError):
            XCTAssertEqual(error, expectedError, "Expected validation error \(expectedError), got \(error)", file: file, line: line)
        default:
            XCTFail("Expected failure with \(expectedError), got \(result) instead", file: file, line: line)
        }

        XCTAssertEqual(httpClient.requests.count, 0, "No HTTP request should be made if validation fails", file: file, line: line)
        XCTAssertTrue(persistence.saveKeychainDataCalls.isEmpty, "No Keychain save should occur if validation fails", file: file, line: line)
        XCTAssertTrue(persistence.tokenStorageMessages.isEmpty, "No TokenStorage interaction should occur if validation fails", file: file, line: line)
        XCTAssertTrue(persistence.offlineStoreMessages.isEmpty, "No OfflineRegistrationStore interaction should occur if validation fails", file: file, line: line)
    }

    private func expectHTTPRequest(from httpClient: HTTPClientSpy, timeout: TimeInterval = 1.0, file: StaticString = #file, line: UInt = #line) async {
        let expectation = XCTestExpectation(description: "Wait for HTTP request from \(file):\(line)")
        let task = Task {
            for _ in 0 ..< 100 {
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

    private func makeToken(value: String = "any-test-token", expiryOffset: TimeInterval = 3600) -> EssentialFeed.Token {
        EssentialFeed.Token(value: value, expiry: Date().addingTimeInterval(expiryOffset))
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

    // MARK: - Spy for Registration Persistence

    private class RegistrationPersistenceSpy: KeychainProtocol, TokenStorage, OfflineRegistrationStore {
        var saveKeychainDataCalls = [(data: Data, key: String)]()
        var saveKeychainReturnValues: [KeychainSaveResult] = []
        var loadKeychainDataCalls = [String]()
        var dataToReturnForLoad: Data?
        var keychainErrorForLoad: Error?

        func save(data: Data, forKey key: String) -> KeychainSaveResult {
            saveKeychainDataCalls.append((data, key))
            return saveKeychainReturnValues.isEmpty ? .success : saveKeychainReturnValues.removeFirst()
        }

        func load(forKey key: String) -> Data? {
            loadKeychainDataCalls.append(key)
            return dataToReturnForLoad
        }

        enum TokenStorageMessage: Equatable {
            case save(Token)
            case loadRefreshToken
        }

        var tokenStorageMessages = [TokenStorageMessage]()
        var saveTokenError: Error?

        func save(_ token: Token) async throws {
            tokenStorageMessages.append(.save(token))
            if let error = saveTokenError {
                throw error
            }
        }

        func loadRefreshToken() async throws -> String? {
            loadRefreshTokenCallsCount += 1
            tokenStorageMessages.append(.loadRefreshToken)
            if let error = loadRefreshTokenError {
                throw error
            }
            return refreshTokenToReturn
        }

        var loadRefreshTokenCallsCount = 0
        var refreshTokenToReturn: String? = "default-spy-refresh-token"
        var loadRefreshTokenError: Error?

        // OfflineRegistrationStore conformance
        enum OfflineStoreMessage: Equatable {
            case save(UserRegistrationData)
        }

        var offlineStoreMessages = [OfflineStoreMessage]()
        var saveOfflineDataError: Error?

        func save(_ data: UserRegistrationData) async throws {
            if let error = saveOfflineDataError {
                offlineStoreMessages.append(.save(data))
                throw error
            }
            offlineStoreMessages.append(.save(data))
        }
    }

    private class UserRegistrationNotifierSpy: UserRegistrationNotifier {
        var notifiedEmailInUse = false
        var notifiedConnectivityError = false
        var registrationFailedError: Error?
        private var receivedErrors: [Error] = []
        private let onNotify: (() -> Void)?

        init(onNotify: (() -> Void)? = nil) {
            self.onNotify = onNotify
        }

        func notifyRegistrationFailed(with error: Error) {
            registrationFailedError = error
            receivedErrors.append(error)

            if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                notifiedConnectivityError = true
            }

            if let regError = error as? UserRegistrationError, regError == .emailAlreadyInUse {
                notifiedEmailInUse = true
            }

            if let networkError = error as? NetworkError, networkError == .noConnectivity {
                notifiedConnectivityError = true
            }

            onNotify?()
        }

        func getReceivedErrors() -> [Error] {
            receivedErrors
        }
    }
}
