@preconcurrency import EssentialFeed
import XCTest

final class GlobalLogoutEndToEndTests: XCTestCase {
    func test_performGlobalLogout_clearsAllStorageResidues() async throws {
        let (sut, dependencies) = makeSUT()

        await populateAllStores(dependencies)
        await verifyDataExists(dependencies)

        try await sut.performGlobalLogout()

        await verifyNoStorageResidues(dependencies)
    }

    func test_performGlobalLogout_whenSomeStoresEmpty_stillClearsOthersWithoutError() async throws {
        let (sut, dependencies) = makeSUT()

        await populateOnlyTokenAndUserDefaults(dependencies)
        await verifyPartialDataExists(dependencies)

        try await sut.performGlobalLogout()

        await verifyNoStorageResidues(dependencies)
    }

    func test_performGlobalLogout_whenAllStoresEmpty_completesWithoutError() async throws {
        let (sut, dependencies) = makeSUT()

        do {
            try await sut.performGlobalLogout()
        } catch {
            XCTFail("Should complete without error when all stores are empty: \(error)")
        }

        await verifyNoStorageResidues(dependencies)
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: GlobalLogoutManager, dependencies: StorageDependencies) {
        let systemKeychain = SystemKeychain()
        let keychainManager = KeychainManager(
            reader: SystemKeychainAdapter(systemKeychain: systemKeychain),
            writer: SystemKeychainAdapter(systemKeychain: systemKeychain),
            encryptor: PassthroughEncryptor(),
            errorHandler: SilentKeychainErrorHandlerAdapter()
        )
        let tokenStorage = KeychainTokenStore(keychainManager: keychainManager, tokenKeychainKey: "e2e-logout-token-\(UUID().uuidString)")
        let offlineLoginStore = InMemoryOfflineLoginStoreAdapter()
        let offlineRegistrationStore = InMemoryOfflineRegistrationStoreSpy()
        let failedLoginStore = InMemoryFailedLoginAttemptsStoreAdapter()
        let sessionUserDefaults = SessionUserDefaultsManager(userDefaults: UserDefaults.standard)

        let sut = GlobalLogoutManager(
            tokenStorage: tokenStorage,
            offlineLoginStore: offlineLoginStore,
            offlineRegistrationStore: offlineRegistrationStore,
            failedLoginAttemptsStore: failedLoginStore,
            sessionUserDefaults: sessionUserDefaults
        )

        let dependencies = StorageDependencies(
            tokenStorage: tokenStorage,
            offlineLoginStore: offlineLoginStore,
            offlineRegistrationStore: offlineRegistrationStore,
            failedLoginStore: failedLoginStore,
            sessionUserDefaults: sessionUserDefaults
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)

        return (sut, dependencies)
    }

    private func populateAllStores(_ dependencies: StorageDependencies) async {
        let token = Token(accessToken: "test-access-token", expiry: Date().addingTimeInterval(3600), refreshToken: "test-refresh-token")
        try? await dependencies.tokenStorage.save(tokenBundle: token)

        let loginCredentials = LoginCredentials(email: "test@example.com", password: "password123")
        await dependencies.offlineLoginStore.saveCredentials(loginCredentials)

        let registrationData = UserRegistrationData(name: "Test User", email: "test@example.com", password: "password123")
        dependencies.offlineRegistrationStore.receivedUserRegistrationData.append(registrationData)

        await dependencies.failedLoginStore.incrementAttempts(for: "test@example.com")

        UserDefaults.standard.set("test_user_123", forKey: "user_id")
        UserDefaults.standard.set("testuser", forKey: "username")
    }

    private func populateOnlyTokenAndUserDefaults(_ dependencies: StorageDependencies) async {
        let token = Token(accessToken: "partial-test-token", expiry: Date().addingTimeInterval(1800), refreshToken: nil)
        try? await dependencies.tokenStorage.save(tokenBundle: token)

        UserDefaults.standard.set("partial_user_456", forKey: "user_id")
        UserDefaults.standard.set(Date(), forKey: "last_login_date")
    }

    private func verifyDataExists(_ dependencies: StorageDependencies) async {
        let loadedToken = try? await dependencies.tokenStorage.loadTokenBundle()
        XCTAssertNotNil(loadedToken, "Token should exist before logout")

        let loginCredentials = dependencies.offlineLoginStore.savedCredentials
        XCTAssertFalse(loginCredentials.isEmpty, "Offline login credentials should exist before logout")

        XCTAssertFalse(dependencies.offlineRegistrationStore.receivedUserRegistrationData.isEmpty, "Offline registration data should exist before logout")

        let userID = UserDefaults.standard.string(forKey: "user_id")
        XCTAssertNotNil(userID, "UserDefaults data should exist before logout")
    }

    private func verifyPartialDataExists(_ dependencies: StorageDependencies) async {
        let loadedToken = try? await dependencies.tokenStorage.loadTokenBundle()
        XCTAssertNotNil(loadedToken, "Token should exist before logout")

        let userID = UserDefaults.standard.string(forKey: "user_id")
        XCTAssertNotNil(userID, "UserDefaults data should exist before logout")
    }

    private func verifyNoStorageResidues(_ dependencies: StorageDependencies) async {
        let loadedToken = try? await dependencies.tokenStorage.loadTokenBundle()
        XCTAssertNil(loadedToken, "No token should remain after logout")

        let loginCredentials = dependencies.offlineLoginStore.savedCredentials
        XCTAssertTrue(loginCredentials.isEmpty, "No offline login credentials should remain after logout")

        XCTAssertTrue(dependencies.offlineRegistrationStore.receivedUserRegistrationData.isEmpty, "No offline registration data should remain after logout")

        XCTAssertEqual(dependencies.failedLoginStore.getAttempts(for: "test@example.com"), 0, "No failed login attempts should remain after logout")

        XCTAssertNil(UserDefaults.standard.string(forKey: "user_id"), "No user_id should remain in UserDefaults after logout")
        XCTAssertNil(UserDefaults.standard.string(forKey: "username"), "No username should remain in UserDefaults after logout")
        XCTAssertNil(UserDefaults.standard.object(forKey: "last_login_date"), "No last_login_date should remain in UserDefaults after logout")
    }
}
