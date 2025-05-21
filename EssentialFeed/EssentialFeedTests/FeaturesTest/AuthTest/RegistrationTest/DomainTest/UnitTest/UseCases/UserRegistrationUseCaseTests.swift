import EssentialFeed
import Security
import XCTest

final class UserRegistrationUseCaseTests: XCTestCase {
    func test_registerUser_withValidDataAndToken_createsUserStoresCredentialsAndToken() async throws {
        let name = "Test User"
        let email = "test@example.com"
        let password = "Password123"
        let expectedTokenToReceiveAndStore = makeToken()
        let serverResponseData = try makeRegistrationServerResponseData(
            name: name, email: email, token: expectedTokenToReceiveAndStore
        )

        let (sut, persistenceSpy, _, httpClientSpy, _) = makeSUT()

        let url =
            httpClientSpy.requests.first?.url ?? URL(string: "https://test-register-endpoint.com")!
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

            let keychainCalls = await persistenceSpy.savedCredentialsCalls
            XCTAssertEqual(keychainCalls.count, 1, "Expected to save credentials once")
            XCTAssertEqual(keychainCalls.first?.email, email, "Expected to save credentials for the correct email")
            XCTAssertEqual(keychainCalls.first?.passwordData, password.data(using: .utf8), "Expected to save correct password data")

            let tokenMessages = await persistenceSpy.tokenStorageMessages
            XCTAssertEqual(tokenMessages.count, 1, "Expected to save token once")
            if case let .save(tokenBundle: savedToken) = tokenMessages.first {
                XCTAssertEqual(
                    savedToken, expectedTokenToReceiveAndStore,
                    "Expected to save the correct token received from server"
                )
            } else {
                XCTFail(
                    "Expected save message in TokenStorageMessages, got \(String(describing: tokenMessages.first))"
                )
            }
        case let .failure(error):
            XCTFail("Expected success, got failure \(error) instead")
        }
    }

    func test_registerUser_withEmptyName_returnsValidationError_andDoesNotCallHTTPOrKeychain() async {
        let validatorStub = RegistrationValidatorTestStub()
        let (sut, persistenceSpy, _, httpClientSpy, _) = makeSUT(validator: validatorStub)
        await assertRegistrationValidation(
            name: "",
            email: "test@email.com",
            password: "Password123",
            expectedError: .emptyName,
            sut: sut,
            httpClientSpy: httpClientSpy,
            persistenceSpy: persistenceSpy,
            validatorStub: validatorStub
        )
    }

    func test_registerUser_withInvalidEmail_returnsValidationError_andDoesNotCallHTTPOrKeychain()
        async
    {
        let validatorStub = RegistrationValidatorTestStub()
        let (sut, persistenceSpy, _, httpClientSpy, _) = makeSUT(validator: validatorStub)
        await assertRegistrationValidation(
            name: "Test User",
            email: "invalid-email",
            password: "Password123",
            expectedError: .invalidEmail,
            sut: sut,
            httpClientSpy: httpClientSpy,
            persistenceSpy: persistenceSpy,
            validatorStub: validatorStub
        )
    }

    func test_registerUser_withWeakPassword_returnsValidationError_andDoesNotCallHTTPOrKeychain()
        async
    {
        let validatorStub = RegistrationValidatorTestStub()
        let (sut, persistenceSpy, _, httpClientSpy, _) = makeSUT(validator: validatorStub)
        await assertRegistrationValidation(
            name: "Test User",
            email: "test@email.com",
            password: "123",
            expectedError: .weakPassword,
            sut: sut,
            httpClientSpy: httpClientSpy,
            persistenceSpy: persistenceSpy,
            validatorStub: validatorStub
        )
    }

    func
        test_registerUser_withValidData_whenTokenStorageFails_returnsErrorAndDoesNotStoreCredentials()
        async throws
    {
        let (sut, persistenceSpy, _, httpClientSpy, _) = makeSUT()

        let tokenFromServer = makeToken()
        let serverResponseData = try makeRegistrationServerResponseData(
            name: "Test User", email: "test@example.com", token: tokenFromServer
        )

        let tokenStorageError = NSError(
            domain: "TokenStorageError", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Failed to save token"]
        )
        await persistenceSpy.setSaveTokenError(tokenStorageError)

        let registerTask = Task {
            await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
        }

        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(
            with: serverResponseData,
            response: HTTPURLResponse(
                url: URL(string: "https://test-register-endpoint.com")!, statusCode: 201, httpVersion: nil,
                headerFields: nil
            )!
        )
        let result = await registerTask.value

        switch result {
        case .success:
            XCTFail("Expected failure due to token storage error, got success instead")
        case let .failure(error):
            XCTAssertEqual(error as NSError, tokenStorageError, "Expected token storage error")
        }
        let keychainCalls = await persistenceSpy.savedCredentialsCalls
        XCTAssertEqual(keychainCalls.count, 0, "Keychain save should not be called if token storage fails")

        let tokenMessages = await persistenceSpy.tokenStorageMessages
        XCTAssertEqual(tokenMessages.count, 1, "Expected TokenStorage save to be attempted once")

        if case let .save(tokenBundle: attemptedToken) = tokenMessages.first {
            XCTAssertEqual(attemptedToken, tokenFromServer, "Expected to attempt saving the correct token")
        } else {
            XCTFail(
                "Expected save message in TokenStorageMessages, got \(String(describing: tokenMessages.first))"
            )
        }
    }

    func test_registerUser_withValidData_whenServerResponseIsMissingOrMalformedToken_returnsError() async throws {
        let (sut, persistenceSpy, _, httpClientSpy, _) = makeSUT()

        let malformedResponseData = Data(
            #"{"user": {"name": "Test User", "email": "test@example.com"}}"#.utf8)

        let registerTask = Task {
            await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
        }

        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(
            with: malformedResponseData,
            response: HTTPURLResponse(
                url: URL(string: "https://test-register-endpoint.com")!, statusCode: 201, httpVersion: nil,
                headerFields: nil
            )!
        )
        let result = await registerTask.value

        switch result {
        case .success:
            XCTFail("Expected failure due to unparseable/missing token response, got success instead")
        case let .failure(error):
            XCTAssertTrue(
                error is DecodingError || error is TokenParsingError,
                "Expected a parsing error or TokenParsingError"
            )
        }
        let keychainCalls = await persistenceSpy.savedCredentialsCalls
        XCTAssertEqual(keychainCalls.count, 0, "Keychain save should not be called if token parsing fails")
        let tokenMessages = await persistenceSpy.tokenStorageMessages
        XCTAssertEqual(tokenMessages.count, 0, "TokenStorage save should not be attempted if token parsing fails")
        let offlineStoreMessages = await persistenceSpy.offlineStoreMessages
        XCTAssertEqual(offlineStoreMessages.count, 0, "OfflineRegistrationStore save should not be attempted if token parsing fails")
    }

    func test_registerUser_withAlreadyRegisteredEmail_notifiesEmailAlreadyInUsePresenter() async {
        let notifierExpectation = expectation(description: "Notifier should be called for email in use")
        let (sut, persistenceSpy, _, httpClientSpy, notifierSpy) = makeSUT(
            notifierSpy: UserRegistrationNotifierSpy(onNotify: { notifierExpectation.fulfill() }))

        let registerTask = Task {
            await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
        }

        await expectHTTPRequest(from: httpClientSpy)

        let response409 = HTTPURLResponse(
            url: httpClientSpy.requests.first?.url ?? URL(string: "https://test-register-endpoint.com")!,
            statusCode: 409, httpVersion: nil, headerFields: nil
        )!
        httpClientSpy.complete(with: Data(), response: response409)
        let result = await registerTask.value

        await fulfillment(of: [notifierExpectation], timeout: 1.0)

        let emailInUseNotified = notifierSpy.wasEmailInUseNotified()
        XCTAssertTrue(emailInUseNotified, "Notifier should be called with emailAlreadyInUse error")
        let keychainCalls = await persistenceSpy.savedCredentialsCalls
        XCTAssertEqual(keychainCalls.count, 0, "Keychain save should not be called on registration failure")
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
        let response409 = HTTPURLResponse(
            url: httpClientSpy.requests.first?.url ?? URL(string: "https://test-register-endpoint.com")!,
            statusCode: 409, httpVersion: nil, headerFields: nil
        )!
        httpClientSpy.complete(with: Data(), response: response409)
        let result = await registerTask.value

        switch result {
        case let .failure(error as UserRegistrationError):
            XCTAssertEqual(error, .emailAlreadyInUse, "Expected .emailAlreadyInUse error")
        default:
            XCTFail("Expected .emailAlreadyInUse error, got \(result) instead")
        }
        let keychainCalls = await persistenceSpy.savedCredentialsCalls
        XCTAssertEqual(keychainCalls.count, 0, "No Keychain save should occur if email is already registered")
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

        let keychainCalls = await persistenceSpy.savedCredentialsCalls
        XCTAssertEqual(keychainCalls.count, 0, "No Keychain save should occur if there is no connectivity")
        let tokenMessages = await persistenceSpy.tokenStorageMessages
        XCTAssertTrue(tokenMessages.isEmpty, "No TokenStorage save should occur if there is no connectivity")
        let offlineStoreMessages = await persistenceSpy.offlineStoreMessages
        XCTAssertEqual(offlineStoreMessages.count, 1, "OfflineRegistrationStore save should occur if there is no connectivity")
    }

    func test_register_whenNoConnectivity_savesDataToOfflineStoreAndReturnsConnectivityError() async throws {
        let (sut, persistenceSpy, _, httpClientSpy, notifierSpy) = makeSUT()
        let expectedUserData = UserRegistrationData(name: "Test User", email: "test@example.com", password: "Password123")

        let registerTask = Task {
            let resgister = await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
            return resgister
        }

        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(
            with: NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue))

        let result = await registerTask.value

        try? await Task.sleep(nanoseconds: 100_000_000)

        let offlineStoreMessages = await persistenceSpy.offlineStoreMessages
        XCTAssertEqual(offlineStoreMessages.count, 1, "Expected to save data once to offline store")
        if let firstMessage = offlineStoreMessages.first {
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

        let connectivityErrorNotified = notifierSpy.wasConnectivityErrorNotified()
        XCTAssertTrue(connectivityErrorNotified, "Notifier should be called with noConnectivity error")
        let keychainCalls = await persistenceSpy.savedCredentialsCalls
        XCTAssertEqual(keychainCalls.count, 0, "Keychain save should not be called on connectivity error")
        let tokenMessages = await persistenceSpy.tokenStorageMessages
        XCTAssertTrue(tokenMessages.isEmpty, "TokenStorage save should not be called on connectivity error")
    }

    // MARK: - Helpers

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
            persistenceService: persistenceSpy,
            validator: validator,
            httpClient: httpClientSpy,
            registrationEndpoint: registrationEndpoint,
            notifier: notifierSpy
        )

        addTeardownBlock {
            [weak sut, weak persistenceSpy, weak validator, weak httpClientSpy, weak notifierSpy] in
            XCTAssertNil(sut, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
            XCTAssertNil(persistenceSpy, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
            XCTAssertNil(validator as AnyObject?, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
            XCTAssertNil(httpClientSpy, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
            XCTAssertNil(notifierSpy, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
        return (sut, persistenceSpy, validator, httpClientSpy, notifierSpy)
    }

    private actor RegistrationPersistenceSpy: @preconcurrency UserRegistrationPersistenceService {
        enum TokenStorageMessage: Equatable {
            case save(tokenBundle: Token)
        }

        enum OfflineStoreMessage: Equatable {
            case save(EssentialFeed.UserRegistrationData)
        }

        public private(set) var savedCredentialsCalls = [(email: String, passwordData: Data)]()
        public private(set) var tokenStorageMessages = [TokenStorageMessage]()
        public private(set) var offlineStoreMessages = [OfflineStoreMessage]()
        private var saveTokenErrorToThrow: Error?
        private var saveCredentialsResult: EssentialFeed.KeychainSaveResult = .success
        private var saveForOfflineProcessingErrorToThrow: Error?

        func setSaveCredentialsResult(_ result: EssentialFeed.KeychainSaveResult) {
            self.saveCredentialsResult = result
        }

        func setSaveForOfflineProcessingError(_ error: Error?) {
            self.saveForOfflineProcessingErrorToThrow = error
        }

        func setSaveTokenError(_ error: Error?) {
            self.saveTokenErrorToThrow = error
        }

        func saveCredentials(passwordData: Data, forEmail email: String)
            -> EssentialFeed.KeychainSaveResult
        {
            savedCredentialsCalls.append((email: email, passwordData: passwordData))
            return saveCredentialsResult
        }

        func save(tokenBundle: EssentialFeed.Token) async throws {
            tokenStorageMessages.append(.save(tokenBundle: tokenBundle))
            if let error = saveTokenErrorToThrow {
                throw error
            }
        }

        func saveForOfflineProcessing(registrationData: EssentialFeed.UserRegistrationData) async throws {
            offlineStoreMessages.append(.save(registrationData))
            if let error = saveForOfflineProcessingErrorToThrow {
                throw error
            }
        }

        func reset() {
            savedCredentialsCalls.removeAll()
            tokenStorageMessages.removeAll()
            offlineStoreMessages.removeAll()
            saveTokenErrorToThrow = nil
            saveCredentialsResult = .success
            saveForOfflineProcessingErrorToThrow = nil
        }
    }

    private func assertRegistrationValidation(
        name: String,
        email: String,
        password: String,
        expectedError: RegistrationValidationError,
        sut: UserRegistrationUseCase,
        httpClientSpy: HTTPClientSpy,
        persistenceSpy: RegistrationPersistenceSpy,
        validatorStub: RegistrationValidatorTestStub,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        validatorStub.errorToReturn = expectedError

        let result = await sut.register(name: name, email: email, password: password)

        switch result {
        case let .failure(error as RegistrationValidationError):
            XCTAssertEqual(error, expectedError, "Expected validation error \(expectedError), got \(error)", file: file, line: line)
        default:
            XCTFail("Expected failure with \(expectedError), got \(result) instead", file: file, line: line)
        }

        XCTAssertEqual(httpClientSpy.requests.count, 0, "No HTTP request should be made if validation fails", file: file, line: line)
        let keychainCalls = await persistenceSpy.savedCredentialsCalls
        XCTAssertTrue(keychainCalls.isEmpty, "No Keychain save should occur if validation fails", file: file, line: line)
        let tokenMessages = await persistenceSpy.tokenStorageMessages
        XCTAssertTrue(tokenMessages.isEmpty, "No TokenStorage interaction should occur if validation fails", file: file, line: line)
        let offlineStoreMessages = await persistenceSpy.offlineStoreMessages
        XCTAssertTrue(offlineStoreMessages.isEmpty, "No OfflineRegistrationStore interaction should occur if validation fails", file: file, line: line)
    }

    private func expectHTTPRequest(
        from httpClient: HTTPClientSpy, timeout: TimeInterval = 1.0, file: StaticString = #file,
        line: UInt = #line
    ) async {
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

    private func makeToken(
        accessToken: String = "any-test-token", expiryOffset: TimeInterval = 3600,
        refreshToken: String? = nil
    ) -> EssentialFeed.Token {
        EssentialFeed.Token(
            accessToken: accessToken, expiry: Date().addingTimeInterval(expiryOffset),
            refreshToken: refreshToken
        )
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

    private class UserRegistrationNotifierSpy: UserRegistrationNotifier {
        private(set) var notifiedEmailInUse = false
        private(set) var notifiedConnectivityError = false
        private(set) var registrationFailedError: Error?
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

        func wasEmailInUseNotified() -> Bool {
            notifiedEmailInUse
        }

        func wasConnectivityErrorNotified() -> Bool {
            notifiedConnectivityError
        }
    }
}
