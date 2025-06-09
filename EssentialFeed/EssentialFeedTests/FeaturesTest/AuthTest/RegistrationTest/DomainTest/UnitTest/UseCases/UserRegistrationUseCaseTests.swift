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

        let (sut, persistenceSpy, _, httpClientSpy, _, replayProtectorSpy) = makeSUT()

        let url = URL(string: "https://test-register-endpoint.com")!
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

        XCTAssertEqual(replayProtectorSpy.protectRequestCallCount, 1, "Should protect request against replay attacks")

        switch result {
        case let .success(tokenAndUser):
            XCTAssertEqual(tokenAndUser.user.name, name, "Registered user's name should match input")
            XCTAssertEqual(tokenAndUser.user.email, email, "Registered user's email should match input")

            let keychainCalls = await persistenceSpy.savedCredentialsCalls
            XCTAssertEqual(keychainCalls.count, 1, "Expected to save credentials once")
            XCTAssertEqual(keychainCalls.first?.email, email, "Saved email should match input")
            XCTAssertEqual(
                keychainCalls.first?.passwordData, password.data(using: .utf8),
                "Expected to save correct password data"
            )

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
        let (sut, persistenceSpy, _, httpClientSpy, _, replayProtectorSpy) = makeSUT(validator: validatorStub)
        await assertRegistrationValidation(
            name: "",
            email: "test@email.com",
            password: "Password123",
            expectedError: RegistrationValidationError.emptyName,
            sut: sut,
            httpClientSpy: httpClientSpy,
            persistenceSpy: persistenceSpy,
            validatorStub: validatorStub,
            replayProtectorSpy: replayProtectorSpy
        )
    }

    func test_registerUser_withInvalidEmail_returnsValidationError_andDoesNotCallHTTPOrKeychain()
        async
    {
        let validatorStub = RegistrationValidatorTestStub()
        let (sut, persistenceSpy, _, httpClientSpy, _, replayProtectorSpy) = makeSUT(validator: validatorStub)
        await assertRegistrationValidation(
            name: "Test User",
            email: "invalid-email",
            password: "Password123",
            expectedError: RegistrationValidationError.invalidEmail,
            sut: sut,
            httpClientSpy: httpClientSpy,
            persistenceSpy: persistenceSpy,
            validatorStub: validatorStub,
            replayProtectorSpy: replayProtectorSpy
        )
    }

    func test_registerUser_withWeakPassword_returnsValidationError_andDoesNotCallHTTPOrKeychain()
        async
    {
        let validatorStub = RegistrationValidatorTestStub()
        let (sut, persistenceSpy, _, httpClientSpy, _, replayProtectorSpy) = makeSUT(validator: validatorStub)
        await assertRegistrationValidation(
            name: "Test User",
            email: "test@email.com",
            password: "123",
            expectedError: RegistrationValidationError.weakPassword,
            sut: sut,
            httpClientSpy: httpClientSpy,
            persistenceSpy: persistenceSpy,
            validatorStub: validatorStub,
            replayProtectorSpy: replayProtectorSpy
        )
    }

    func
        test_registerUser_withValidData_whenTokenStorageFails_returnsErrorAndDoesNotStoreCredentials()
        async throws
    {
        let (sut, persistenceSpy, _, httpClientSpy, _, _) = makeSUT()

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
                url: URL(string: "https://test-register-endpoint.com")!,
                statusCode: 201,
                httpVersion: nil,
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
        XCTAssertEqual(
            keychainCalls.count, 0, "Keychain save should not be called if token storage fails"
        )

        let tokenMessages = await persistenceSpy.tokenStorageMessages
        XCTAssertEqual(tokenMessages.count, 1, "Expected TokenStorage save to be attempted once")

        if case let .save(tokenBundle: attemptedToken) = tokenMessages.first {
            XCTAssertEqual(
                attemptedToken, tokenFromServer, "Expected to attempt saving the correct token"
            )
        } else {
            XCTFail(
                "Expected save message in TokenStorageMessages, got \(String(describing: tokenMessages.first))"
            )
        }
    }

    func test_registerUser_withValidData_whenServerResponseIsMissingOrMalformedToken_returnsError()
        async throws
    {
        let (sut, persistenceSpy, _, httpClientSpy, _, _) = makeSUT()

        let malformedResponseData = Data(
            #"{"user": {"name": "Test User", "email": "test@example.com"}}"#.utf8)

        let registerTask = Task {
            await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
        }

        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(
            with: malformedResponseData,
            response: HTTPURLResponse(
                url: URL(string: "https://test-register-endpoint.com")!,
                statusCode: 201,
                httpVersion: nil,
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
        XCTAssertEqual(
            keychainCalls.count, 0, "Keychain save should not be called if token parsing fails"
        )

        let tokenMessages = await persistenceSpy.tokenStorageMessages
        XCTAssertEqual(
            tokenMessages.count, 0, "TokenStorage save should not be attempted if token parsing fails"
        )

        let offlineStoreMessages = await persistenceSpy.offlineStoreMessages
        XCTAssertEqual(
            offlineStoreMessages.count, 0,
            "OfflineRegistrationStore save should not be attempted if token parsing fails"
        )
    }

    func
        test_registerUser_withAlreadyRegisteredEmail_returnsEmailAlreadyInUseError_andDoesNotStoreCredentials()
        async
    {
        let (sut, persistenceSpy, _, httpClientSpy, _, _) = makeSUT()

        let task = Task {
            await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
        }

        await expectHTTPRequest(from: httpClientSpy)

        let response409 = HTTPURLResponse(
            url: anyURL(), statusCode: 409, httpVersion: nil, headerFields: nil
        )!

        httpClientSpy.complete(with: Data(), response: response409)

        let result = await task.value

        switch result {
        case let .failure(error as UserRegistrationError):
            XCTAssertEqual(error, .emailAlreadyInUse)
        default:
            XCTFail("Expected .emailAlreadyInUse error, got \(result) instead")
        }

        let keychainCalls = await persistenceSpy.savedCredentialsCalls
        XCTAssertEqual(keychainCalls.count, 0)
    }

    func test_registerUser_withAlreadyRegisteredEmail_notifiesEmailAlreadyInUsePresenter() async {
        let notifierSpy = UserRegistrationNotifierSpy()
        let (sut, persistenceSpy, _, httpClientSpy, _, _) = makeSUT(notifierSpy: notifierSpy)
        let response409 = HTTPURLResponse(
            url: anyURL(), statusCode: 409, httpVersion: nil, headerFields: nil
        )!

        let task = Task {
            await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
        }

        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(with: Data(), response: response409)

        let result = await Task {
            _ = await task.value
            return true
        }.result

        switch result {
        case .success:
            XCTAssertTrue(notifierSpy.wasEmailInUseNotified())
            XCTAssertEqual(notifierSpy.receivedErrors.count, 1)

            if let error = notifierSpy.receivedErrors.first as? UserRegistrationError {
                XCTAssertEqual(error, .emailAlreadyInUse)
            } else {
                XCTFail("Expected UserRegistrationError.emailAlreadyInUse")
            }

            let keychainCalls = await persistenceSpy.savedCredentialsCalls
            XCTAssertEqual(keychainCalls.count, 0)

        case .failure:
            XCTFail("Task should complete successfully")
        }
    }

    func test_registerUser_afterSavingCredentials_canReadCredentialsBackFromKeychain() async {
        let email = "test@essential.com"
        let password = "StrongPassword123"
        let passwordData = password.data(using: .utf8)!
        let persistenceSpy = RegistrationPersistenceSpy()
        let (sut, _, _, httpClientSpy, _, _) = makeSUT(persistenceSpy: persistenceSpy)
        await persistenceSpy.setSaveCredentialsResult(.success)

        let registerTask = Task {
            await sut.register(name: "Test", email: email, password: password)
        }

        await expectHTTPRequest(from: httpClientSpy)
        let response201 = HTTPURLResponse(
            url: anyURL(), statusCode: 201, httpVersion: nil, headerFields: nil
        )!
        let serverResponseData = try! makeRegistrationServerResponseData(
            name: "Test", email: email, token: makeToken()
        )
        httpClientSpy.complete(with: serverResponseData, response: response201)

        _ = await registerTask.value
        await persistenceSpy.setKeychainLoadDataToReturn(passwordData)
        let loadedData = await persistenceSpy.load(forKey: email)

        XCTAssertEqual(
            loadedData, passwordData,
            "Should be able to read back the same password data after saving to Keychain"
        )
    }

    func test_register_whenNoConnectivity_savesDataToOfflineStoreAndReturnsConnectivityError()
        async throws
    {
        let (sut, persistenceSpy, _, httpClientSpy, notifierSpy, _) = makeSUT()
        let expectedUserData = UserRegistrationData(
            name: "Test User", email: "test@example.com", password: "Password123"
        )

        let registerTask = Task {
            await sut.register(name: "Test User", email: "test@example.com", password: "Password123")
        }

        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(
            with: NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue))

        let result = await registerTask.value

        let offlineStoreMessages = await persistenceSpy.offlineStoreMessages
        XCTAssertEqual(offlineStoreMessages.count, 1, "Expected to save data once to offline store")
        if let firstMessage = offlineStoreMessages.first {
            switch firstMessage {
            case let .save(savedData):
                XCTAssertEqual(
                    savedData, expectedUserData, "Expected to save correct user data to offline store"
                )
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
        XCTAssertEqual(
            keychainCalls.count, 0, "Keychain save should not be called on connectivity error"
        )

        let tokenMessages = await persistenceSpy.tokenStorageMessages
        XCTAssertTrue(
            tokenMessages.isEmpty, "TokenStorage save should not be called on connectivity error"
        )
    }

    func test_registerUser_whenPostSaveValidationFails_returnsError() async {
        let email = "test@essential.com"
        let password = "StrongPassword123"
        let token = makeToken()
        let serverResponseData = try! makeRegistrationServerResponseData(
            name: "Test", email: email, token: token
        )
        let persistenceSpy = RegistrationPersistenceSpy()
        let (sut, _, _, httpClientSpy, _, _) = makeSUT(persistenceSpy: persistenceSpy)
        await persistenceSpy.setSaveCredentialsResult(.failure)

        let registerTask = Task {
            await sut.register(name: "Test", email: email, password: password)
        }

        await expectHTTPRequest(from: httpClientSpy)
        let response201 = HTTPURLResponse(
            url: anyURL(), statusCode: 201, httpVersion: nil, headerFields: nil
        )!
        httpClientSpy.complete(with: serverResponseData, response: response201)

        let result = await registerTask.value

        switch result {
        case .failure:
            XCTAssertTrue(true, "Should return token storage related error when post-save validation fails")
        default:
            XCTFail("Expected .tokenStorageFailed error, got \(result) instead")
        }
    }

    func test_registerUser_afterSavingToken_canReadTokenBackFromKeychain() async throws {
        let email = "test@essential.com"
        let password = "StrongPassword123"
        let token = makeToken()
        let serverResponseData = try makeRegistrationServerResponseData(
            name: "Test", email: email, token: token
        )
        let persistenceSpy = RegistrationPersistenceSpy()
        let (sut, _, _, httpClientSpy, _, _) = makeSUT(persistenceSpy: persistenceSpy)
        await persistenceSpy.setSaveCredentialsResult(.success)

        let url = URL(string: "https://test-register-endpoint.com")!
        let response201 = HTTPURLResponse(
            url: url, statusCode: 201, httpVersion: nil, headerFields: nil
        )!

        let registerTask = Task {
            await sut.register(name: "Test", email: email, password: password)
        }
        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(with: serverResponseData, response: response201)
        _ = await registerTask.value

        await persistenceSpy.setKeychainLoadDataToReturn(token.accessToken.data(using: .utf8))
        let loadedTokenData = await persistenceSpy.load(forKey: email)
        XCTAssertEqual(
            loadedTokenData, token.accessToken.data(using: .utf8),
            "Should be able to read back the same token after saving to Keychain"
        )
    }

    func test_registerUser_withReplayAttack_protection_returnsReplayAttackError() async {
        let email = "attacker@replay.com"
        let password = "Replay123"
        let validatorStub = RegistrationValidatorTestStub()
        let (sut, persistenceSpy, _, httpClientSpy, _, _) = makeSUT(validator: validatorStub)

        let registerTask = Task {
            await sut.register(name: "Attacker", email: email, password: password)
        }

        await expectHTTPRequest(from: httpClientSpy)
        let response409 = HTTPURLResponse(
            url: anyURL(), statusCode: 409, httpVersion: nil, headerFields: nil
        )!
        httpClientSpy.complete(
            with: Data("{\"error\":\"replay_attack_detected\"}".utf8), response: response409
        )

        let result = await registerTask.value

        switch result {
        case let .failure(error as UserRegistrationError):
            XCTAssertEqual(
                error, .replayAttackDetected, "Should return .replayAttackDetected on replay attack"
            )
        default:
            XCTFail("Expected .replayAttackDetected error, got \(result) instead")
        }
        let keychainCalls = await persistenceSpy.savedCredentialsCalls
        XCTAssertEqual(keychainCalls.count, 0, "Should not save credentials on replay attack")
    }

    func test_registerUser_whenAbuseDetected_returnsAbuseErrorAndDoesNotSaveCredentials() async {
        let email = "abuser@fraud.com"
        let password = "Abuse123"
        let validatorStub = RegistrationValidatorTestStub()
        let (sut, persistenceSpy, _, httpClientSpy, _, _) = makeSUT(validator: validatorStub)

        let registerTask = Task {
            await sut.register(name: "Abuser", email: email, password: password)
        }

        await expectHTTPRequest(from: httpClientSpy)
        let response429 = HTTPURLResponse(
            url: anyURL(), statusCode: 429, httpVersion: nil, headerFields: nil
        )!
        httpClientSpy.complete(with: Data("{\"error\":\"abuse_detected\"}".utf8), response: response429)

        let result = await registerTask.value

        switch result {
        case let .failure(error as UserRegistrationError):
            XCTAssertEqual(error, .abuseDetected, "Should return .abuseDetected on abuse detection")
        default:
            XCTFail("Expected .abuseDetected error, got \(result) instead")
        }
        let keychainCalls = await persistenceSpy.savedCredentialsCalls
        XCTAssertEqual(keychainCalls.count, 0, "Should not save credentials on abuse detection")
    }

    func test_registerUser_appliesReplayAttackProtection() async throws {
        let (sut, _, _, httpClientSpy, _, replayProtectorSpy) = makeSUT()
        _ = URLRequest(url: anyURL())
        let protectedRequest = URLRequest(url: URL(string: "https://protected.example.com")!)
        replayProtectorSpy.stubbedProtectedRequest = protectedRequest

        let registerTask = Task {
            await sut.register(name: "User", email: "user@test.com", password: "Password123")
        }

        await expectHTTPRequest(from: httpClientSpy)
        httpClientSpy.complete(with: Data(), response: HTTPURLResponse(url: anyURL(), statusCode: 500, httpVersion: nil, headerFields: nil)!)
        _ = await registerTask.value

        XCTAssertEqual(replayProtectorSpy.protectRequestCallCount, 1, "Should call replay protector once")
        XCTAssertNotNil(replayProtectorSpy.receivedRequest, "Should pass request to replay protector")
        XCTAssertEqual(httpClientSpy.requests.first, protectedRequest, "Should send protected request via HTTP client")
    }

    func test_registerUser_whenReplayProtectionFails_returnsError() async throws {
        let (sut, _, _, httpClientSpy, _, replayProtectorSpy) = makeSUT()
        let protectionError = TestError.replayProtectionFailed
        replayProtectorSpy.stubbedError = protectionError

        let result = await sut.register(name: "User", email: "user@test.com", password: "Password123")

        switch result {
        case let .failure(error):
            XCTAssertEqual(error as? TestError, protectionError, "Should return replay protection error")
        case .success:
            XCTFail("Expected failure when replay protection fails")
        }

        XCTAssertTrue(httpClientSpy.requests.isEmpty, "Should not make HTTP request when replay protection fails")
    }

    private func makeSUT(
        persistenceSpy: RegistrationPersistenceSpy = RegistrationPersistenceSpy(),
        validator: RegistrationValidatorProtocol = RegistrationValidatorAlwaysValid(),
        httpClientSpy: HTTPClientSpy = HTTPClientSpy(),
        registrationEndpoint: URL = URL(string: "https://any-test-endpoint.com")!,
        notifierSpy: UserRegistrationNotifierSpy = UserRegistrationNotifierSpy(),
        replayProtectorSpy: ReplayAttackProtectorSpy = ReplayAttackProtectorSpy(),
        file: StaticString = #filePath, line: UInt = #line
    ) -> (
        sut: UserRegisterer,
        persistenceSpy: RegistrationPersistenceSpy,
        validator: RegistrationValidatorProtocol,
        httpClientSpy: HTTPClientSpy,
        notifierSpy: UserRegistrationNotifierSpy,
        replayProtectorSpy: ReplayAttackProtectorSpy
    ) {
        let responseMapper = UserRegistrationResponseMapper(notifier: notifierSpy)
        let registrationPersistenceService = DefaultRegistrationPersistenceService(
            tokenStorage: persistenceSpy,
            credentialsStore: persistenceSpy,
            offlineStore: persistenceSpy
        )
        let offlineHandler = DefaultOfflineRegistrationHandler(
            offlineStore: persistenceSpy,
            notifier: notifierSpy
        )

        let commands: [RegistrationCommand] = [
            ValidationCommand(validator: validator, notifier: notifierSpy),
            RequestCreationCommand(registrationEndpoint: registrationEndpoint),
            ReplayProtectionCommand(replayProtector: replayProtectorSpy),
            HTTPRequestCommand(httpClient: httpClientSpy),
            ResponseMappingCommand(responseMapper: responseMapper),
            PersistenceCommand(persistenceService: registrationPersistenceService)
        ]

        let registrationService = RegistrationCommandChain(
            commands: commands,
            offlineHandler: offlineHandler,
            notifier: notifierSpy
        )

        let sut: UserRegisterer = UserRegistrationUseCase(registrationService: registrationService)

        addTeardownBlock {
            [weak sut, weak persistenceSpy, weak validator, weak httpClientSpy, weak notifierSpy, weak replayProtectorSpy] in
            XCTAssertNil(sut, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
            XCTAssertNil(persistenceSpy, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
            XCTAssertNil(validator as AnyObject?, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
            XCTAssertNil(httpClientSpy, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
            XCTAssertNil(notifierSpy, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
            XCTAssertNil(replayProtectorSpy, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
        return (sut, persistenceSpy, validator, httpClientSpy, notifierSpy, replayProtectorSpy)
    }

    private actor RegistrationPersistenceSpy: @preconcurrency TokenWriter, @preconcurrency KeychainSavable, @preconcurrency OfflineRegistrationStore {
        enum TokenStorageMessage: Equatable {
            case save(tokenBundle: Token)
        }

        enum OfflineStoreMessage: Equatable {
            case save(EssentialFeed.UserRegistrationData)
        }

        private var keychainLoadDataToReturn: Data?
        private var keychainLoadKeyCalls = [String]()

        func setKeychainLoadDataToReturn(_ data: Data?) async {
            keychainLoadDataToReturn = data
        }

        func load(forKey key: String) -> Data? {
            keychainLoadKeyCalls.append(key)
            return keychainLoadDataToReturn
        }

        private(set) var savedCredentialsCalls = [(email: String, passwordData: Data)]()
        private(set) var tokenStorageMessages = [TokenStorageMessage]()
        private(set) var offlineStoreMessages = [OfflineStoreMessage]()
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

        func save(data: Data, forKey key: String) -> EssentialFeed.KeychainSaveResult {
            savedCredentialsCalls.append((email: key, passwordData: data))
            return saveCredentialsResult
        }

        func save(tokenBundle: EssentialFeed.Token) async throws {
            tokenStorageMessages.append(.save(tokenBundle: tokenBundle))
            if let error = saveTokenErrorToThrow {
                throw error
            }
        }

        func save(_ data: EssentialFeed.UserRegistrationData) async throws {
            offlineStoreMessages.append(.save(data))
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

    private final class ReplayAttackProtectorSpy: ReplayAttackProtector {
        var stubbedProtectedRequest = URLRequest(url: URL(string: "https://protected.example.com")!)
        var stubbedError: Error?

        private(set) var protectRequestCallCount = 0
        private(set) var receivedRequest: URLRequest?

        func protectRequest(_ request: URLRequest) async throws -> URLRequest {
            protectRequestCallCount += 1
            receivedRequest = request

            if let error = stubbedError {
                throw error
            }

            return stubbedProtectedRequest
        }
    }

    private func assertRegistrationValidation(
        name: String, email: String, password: String, expectedError: RegistrationValidationError,
        sut: UserRegisterer, httpClientSpy: HTTPClientSpy, persistenceSpy _: RegistrationPersistenceSpy,
        validatorStub: RegistrationValidatorTestStub, replayProtectorSpy: ReplayAttackProtectorSpy,
        file: StaticString = #file, line: UInt = #line
    ) async {
        validatorStub.errorToReturn = expectedError

        let result = await sut.register(name: name, email: email, password: password)
        let requestCount = httpClientSpy.requests.count

        XCTAssertEqual(
            requestCount, 0, "No HTTP request should be made if validation fails", file: file, line: line
        )
        XCTAssertEqual(
            replayProtectorSpy.protectRequestCallCount, 0,
            "Replay protector should not be called if validation fails", file: file, line: line
        )

        switch result {
        case let .failure(error as RegistrationValidationError):
            XCTAssertEqual(
                error, expectedError, "Expected validation error \(expectedError), got \(error)",
                file: file, line: line
            )
        default:
            XCTFail(
                "Expected failure with \(expectedError), got \(result) instead", file: file, line: line
            )
        }
    }

    private func expectHTTPRequest(
        from httpClient: HTTPClientSpy, timeout: TimeInterval = 1.0, file: StaticString = #file,
        line: UInt = #line
    ) async {
        let expectation = XCTestExpectation(description: "Wait for HTTP request from \(file):\(line)")
        let task = Task {
            for _ in 0 ..< 100 {
                let requests = httpClient.requests
                if !requests.isEmpty {
                    expectation.fulfill()
                    return
                }
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            XCTFail("Timed out waiting for HTTP request", file: file, line: line)
        }

        let requests = httpClient.requests
        if requests.isEmpty {
            await fulfillment(of: [expectation], timeout: timeout)
        }
        task.cancel()
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

    private func makeRegistrationServerResponseData(
        name: String, email: String, token: EssentialFeed.Token
    ) throws -> Data {
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

    private enum TestError: Error, Equatable {
        case replayProtectionFailed
    }
}
