import EssentialFeed
import Security
import XCTest

final class UserRegistrationUseCaseTests: XCTestCase {
    private func makeSUT(
        persistenceSpy: RegistrationPersistenceSpy = RegistrationPersistenceSpy(),
        validator: RegistrationValidatorProtocol = RegistrationValidatorAlwaysValid(),
        httpClientSpy: HTTPClientSpy = HTTPClientSpy(),
        registrationEndpoint: URL = URL(string: "https://any-test-endpoint.com")!,
        notifierSpy: UserRegistrationNotifierSpy = UserRegistrationNotifierSpy(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: UserRegistrationUseCase,
        persistenceSpy: RegistrationPersistenceSpy,
        validator: RegistrationValidatorProtocol,
        httpClientSpy: HTTPClientSpy,
        notifierSpy: UserRegistrationNotifierSpy
    ) {
        let sut = UserRegistrationUseCase(
            persistence: persistenceSpy,
            validator: validator,
            httpClient: httpClientSpy,
            registrationEndpoint: registrationEndpoint,
            notifier: notifierSpy
        )
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(persistenceSpy, file: file, line: line)
        trackForMemoryLeaks(httpClientSpy, file: file, line: line)
        trackForMemoryLeaks(notifierSpy, file: file, line: line)
        return (sut, persistenceSpy, validator, httpClientSpy, notifierSpy)
    }

    func test_registerUser_withValidDataAndToken_createsUserStoresCredentialsAndToken() async throws {
        let name = "Test User"
        let email = "test@example.com"
        let password = "Password123"
        let expectedTokenToReceiveAndStore = makeToken()
        let serverResponseData = try makeRegistrationServerResponseData(name: name, email: email, token: expectedTokenToReceiveAndStore)

        let (sut, persistenceSpy, _, httpClientSpy, _) = makeSUT()

        let url = httpClientSpy.requests.first?.url ?? URL(string: "https://test-register-endpoint.com")!
        let response201 = HTTPURLResponse(
            url: url,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )!

        let registerTask = Task {
            await sut.register(name: name, email: email, password: password)
        }

        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(with: serverResponseData, response: response201)
        let result = await registerTask.value

        switch result {
        case let .success(user):
            XCTAssertEqual(user.name, name, "Registered user's name should match input")
            XCTAssertEqual(user.email, email, "Registered user's email should match input")

            XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.count, 1, "Expected to save credentials once")
            XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.first?.key, email, "Expected to save credentials for the correct email")
            XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.first?.data, password.data(using: .utf8), "Expected to save correct password data")

            XCTAssertEqual(persistenceSpy.tokenStorageMessages.count, 1, "Expected to save token once")
            if case let .save(tokenBundle: savedToken) = persistenceSpy.tokenStorageMessages.first {
                XCTAssertEqual(savedToken, expectedTokenToReceiveAndStore, "Expected to save the correct token received from server")
            } else {
                XCTFail("Expected save message in TokenStorageMessages, got \(String(describing: persistenceSpy.tokenStorageMessages.first))")
            }
        case let .failure(error):
            XCTFail("Expected success, got failure \(error) instead")
        }
    }

    func test_registerUser_withEmptyName_returnsValidationError_andDoesNotCallHTTPOrKeychain() async {
        let (_, persistenceSpy, _, _, _) = makeSUT()
        await assertRegistrationValidation(
            name: "",
            email: "test@email.com",
            password: "Password123",
            expectedError: .emptyName,
            persistence: persistenceSpy
        )
    }

    func test_registerUser_withInvalidEmail_returnsValidationError_andDoesNotCallHTTPOrKeychain() async {
        let (_, persistenceSpy, _, _, _) = makeSUT()
        await assertRegistrationValidation(
            name: "Test User",
            email: "invalid-email",
            password: "Password123",
            expectedError: .invalidEmail,
            persistence: persistenceSpy
        )
    }

    func test_registerUser_withWeakPassword_returnsValidationError_andDoesNotCallHTTPOrKeychain() async {
        let (_, persistenceSpy, _, _, _) = makeSUT()
        await assertRegistrationValidation(
            name: "Test User",
            email: "test@email.com",
            password: "123",
            expectedError: .weakPassword,
            persistence: persistenceSpy
        )
    }

    func test_registerUser_withValidData_whenTokenStorageFails_returnsErrorAndDoesNotStoreCredentials() async throws {
        let (sut, persistenceSpy, _, httpClientSpy, _) = makeSUT()

        let tokenFromServer = makeToken()
        let serverResponseData = try makeRegistrationServerResponseData(name: "Test User", email: "test@example.com", token: tokenFromServer)

        let tokenStorageError = NSError(domain: "TokenStorageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to save token"])
        persistenceSpy.saveTokenError = tokenStorageError

        let registerTask = Task {
            await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
        }

        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(with: serverResponseData, response: HTTPURLResponse(url: URL(string: "https://test-register-endpoint.com")!, statusCode: 201, httpVersion: nil, headerFields: nil)!)
        let result = await registerTask.value

        switch result {
        case .success:
            XCTFail("Expected failure due to token storage error, got success instead")
        case let .failure(error):
            XCTAssertEqual(error as NSError, tokenStorageError, "Expected token storage error")
        }
        XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.count, 0, "Keychain save should not be called if token storage fails")
        XCTAssertEqual(persistenceSpy.tokenStorageMessages.count, 1, "Expected TokenStorage save to be attempted once")
        if case let .save(tokenBundle: attemptedToken) = persistenceSpy.tokenStorageMessages.first {
            XCTAssertEqual(attemptedToken, tokenFromServer, "Expected to attempt saving the correct token")
        } else {
            XCTFail("Expected save message in TokenStorageMessages, got \(String(describing: persistenceSpy.tokenStorageMessages.first))")
        }
    }

    func test_registerUser_withValidData_whenServerResponseIsMissingOrMalformedToken_returnsError() async throws {
        let (sut, persistenceSpy, _, httpClientSpy, _) = makeSUT()

        let malformedResponseData = Data(#"{"user": {"name": "Test User", "email": "test@example.com"}}"#.utf8)

        let registerTask = Task {
            await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
        }

        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(with: malformedResponseData, response: HTTPURLResponse(url: URL(string: "https://test-register-endpoint.com")!, statusCode: 201, httpVersion: nil, headerFields: nil)!)
        let result = await registerTask.value

        switch result {
        case .success:
            XCTFail("Expected failure due to unparseable/missing token response, got success instead")
        case let .failure(error):
            XCTAssertTrue(error is DecodingError || error is TokenParsingError, "Expected a parsing error or TokenParsingError")
        }
        XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.count, 0, "Keychain save should not be called if token parsing fails")
        XCTAssertEqual(persistenceSpy.tokenStorageMessages.count, 0, "TokenStorage save should not be attempted if token parsing fails")
    }

    func test_registerUser_withAlreadyRegisteredEmail_notifiesEmailAlreadyInUsePresenter() async {
        let notifierExpectation = expectation(description: "Notifier should be called for email in use")
        let (sut, persistenceSpy, _, httpClientSpy, notifierSpy) = makeSUT(notifierSpy: UserRegistrationNotifierSpy(onNotify: { notifierExpectation.fulfill() }))

        let registerTask = Task {
            await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
        }

        await expectHTTPRequest(from: httpClientSpy)

        let response409 = HTTPURLResponse(url: httpClientSpy.requests.first?.url ?? URL(string: "https://test-register-endpoint.com")!, statusCode: 409, httpVersion: nil, headerFields: nil)!
        httpClientSpy.complete(with: Data(), response: response409)

        let result = await registerTask.value

        await fulfillment(of: [notifierExpectation], timeout: 1.0)

        XCTAssertTrue(notifierSpy.notifiedEmailInUse, "Notifier should be called with emailAlreadyInUse error")
        XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.count, 0, "Keychain save should not be called on registration failure")
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
        let (sut, persistenceSpy, _, httpClientSpy, _) = makeSUT()

        let registerTask = Task {
            await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
        }
        let requestRegistered = expectation(description: "Request registered")
        Task {
            while httpClientSpy.requests.isEmpty {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            requestRegistered.fulfill()
        }
        await fulfillment(of: [requestRegistered], timeout: 1.0)
        let response409 = HTTPURLResponse(url: httpClientSpy.requests.first?.url ?? URL(string: "https://test-register-endpoint.com")!, statusCode: 409, httpVersion: nil, headerFields: nil)!
        httpClientSpy.complete(with: Data(), response: response409)
        let result = await registerTask.value

        switch result {
        case let .failure(error as UserRegistrationError):
            XCTAssertEqual(error, .emailAlreadyInUse, "Expected .emailAlreadyInUse error")
        default:
            XCTFail("Expected .emailAlreadyInUse error, got \(result) instead")
        }
        XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.count, 0, "No Keychain save should occur if email is already registered")
    }

    func test_registerUser_withNoConnectivity_returnsConnectivityError_andDoesNotStoreCredentials() async {
        let (sut, persistenceSpy, _, httpClientSpy, _) = makeSUT()
        let requestRegistered = expectation(description: "Request registered")

        Task {
            _ = await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
            requestRegistered.fulfill()
        }

        let start = Date()
        while httpClientSpy.requests.isEmpty {
            if Date().timeIntervalSince(start) > 0.9 {
                XCTFail("HTTPClientSpy never received a request")
                break
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        httpClientSpy.complete(with: NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue, userInfo: nil))

        await fulfillment(of: [requestRegistered], timeout: 1.0)

        XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.count, 0, "No Keychain save should occur if there is no connectivity")
        XCTAssertTrue(persistenceSpy.tokenStorageMessages.isEmpty, "No TokenStorage save should occur if there is no connectivity")
    }

    func test_register_whenNoConnectivity_savesDataToOfflineStoreAndReturnsConnectivityError() async throws {
        let (sut, persistenceSpy, _, httpClientSpy, notifierSpy) = makeSUT()
        let expectedUserData = UserRegistrationData(name: "Test User", email: "test@example.com", password: "Password123")

        let registerTask = Task {
            let res = await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
            return res
        }

        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(with: NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue))

        let result = await registerTask.value

        XCTAssertEqual(persistenceSpy.offlineStoreMessages.count, 1, "Expected to save data once to offline store")
        if let firstMessage = persistenceSpy.offlineStoreMessages.first {
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

        XCTAssertTrue(notifierSpy.notifiedConnectivityError, "Notifier should be called with noConnectivity error")
        XCTAssertEqual(persistenceSpy.saveKeychainDataCalls.count, 0, "Keychain save should not be called on connectivity error")
        XCTAssertTrue(persistenceSpy.tokenStorageMessages.isEmpty, "TokenStorage save should not be called on connectivity error")
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
        let (sut, _, _, httpClientSpy, _) = makeSUT(persistenceSpy: persistence, validator: validator)

        let result = await sut.register(name: name, email: email, password: password)

        switch result {
        case let .failure(error as RegistrationValidationError):
            XCTAssertEqual(error, expectedError, "Expected validation error \(expectedError), got \(error)", file: file, line: line)
        default:
            XCTFail("Expected failure with \(expectedError), got \(result) instead", file: file, line: line)
        }

        XCTAssertEqual(httpClientSpy.requests.count, 0, "No HTTP request should be made if validation fails", file: file, line: line)
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

    private func makeToken(accessToken: String = "any-test-token", expiryOffset: TimeInterval = 3600, refreshToken: String? = nil) -> EssentialFeed.Token {
        EssentialFeed.Token(accessToken: accessToken, expiry: Date().addingTimeInterval(expiryOffset), refreshToken: refreshToken)
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
            token: .init(value: token.accessToken, expiry: token.expiry)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(responsePayload)
    }

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
            if keychainErrorForLoad != nil {}
            return dataToReturnForLoad
        }

        enum TokenStorageMessage: Equatable {
            case save(tokenBundle: Token)
            case loadTokenBundle
            case deleteTokenBundle
        }

        var tokenStorageMessages = [TokenStorageMessage]()
        var saveTokenError: Error?
        var tokenBundleToReturn: Token?
        var loadTokenBundleError: Error?
        var deleteTokenBundleError: Error?

        func save(tokenBundle: Token) async throws {
            tokenStorageMessages.append(.save(tokenBundle: tokenBundle))
            if let error = saveTokenError {
                throw error
            }
        }

        func loadTokenBundle() async throws -> Token? {
            tokenStorageMessages.append(.loadTokenBundle)
            if let error = loadTokenBundleError {
                throw error
            }
            return tokenBundleToReturn
        }

        func deleteTokenBundle() async throws {
            tokenStorageMessages.append(.deleteTokenBundle)
            if let error = deleteTokenBundleError {
                throw error
            }
        }

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
