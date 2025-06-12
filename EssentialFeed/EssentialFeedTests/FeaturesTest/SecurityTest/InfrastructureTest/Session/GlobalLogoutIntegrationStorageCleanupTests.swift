import EssentialFeed
import XCTest

final class GlobalLogoutIntegrationStorageCleanupTests: XCTestCase {
    override func setUp() {
        super.setUp()
        cleanupTestData()
    }

    override func tearDown() {
        cleanupTestData()
        super.tearDown()
    }

    func test_performGlobalLogout_deletesAllDataFromKeychain() async throws {
        let (sut, keychainStore, userDefaults) = makeSUT()
        let testToken = Token(accessToken: "test-access-token", expiry: Date().addingTimeInterval(3600), refreshToken: "test-refresh-token")

        try await keychainStore.save(tokenBundle: testToken)
        let savedToken = try await keychainStore.loadTokenBundle()
        XCTAssertNotNil(savedToken, "Token should be saved before logout")

        try await sut.performGlobalLogout()

        let deletedToken = try await keychainStore.loadTokenBundle()
        XCTAssertNil(deletedToken, "Token should be deleted from Keychain after global logout")
    }

    func test_performGlobalLogout_deletesAllDataFromUserDefaults() async throws {
        let (sut, _, userDefaults) = makeSUT()
        let testKey = "test-session-key"
        let testValue = "test-session-value"

        userDefaults.set(testValue, forKey: testKey)
        XCTAssertEqual(userDefaults.string(forKey: testKey), testValue, "Value should be saved before logout")

        try await sut.performGlobalLogout()

        XCTAssertNil(userDefaults.string(forKey: testKey), "Session data should be deleted from UserDefaults after global logout")
    }

    func test_performGlobalLogout_deletesOfflineLoginData() async throws {
        let (sut, _, _, offlineLoginStore) = makeSUT()
        let testCredentials = LoginCredentials(email: "test@example.com", password: "password123")

        try await offlineLoginStore.save(credentials: testCredentials)
        let savedRequests = try await offlineLoginStore.loadAll()
        XCTAssertFalse(savedRequests.isEmpty, "Offline login data should be saved before logout")

        try await sut.performGlobalLogout()

        let deletedRequests = try await offlineLoginStore.loadAll()
        XCTAssertTrue(deletedRequests.isEmpty, "Offline login data should be deleted after global logout")
    }

    func test_performGlobalLogout_deletesOfflineRegistrationData() async throws {
        let (sut, _, _, _, offlineRegistrationStore) = makeSUT()
        let testRegistrationData = UserRegistrationData(name: "Test User", email: "test@example.com", password: "password123")

        try await offlineRegistrationStore.save(userData: testRegistrationData)
        let savedRequests = try await offlineRegistrationStore.loadAll()
        XCTAssertFalse(savedRequests.isEmpty, "Offline registration data should be saved before logout")

        try await sut.performGlobalLogout()

        let deletedRequests = try await offlineRegistrationStore.loadAll()
        XCTAssertTrue(deletedRequests.isEmpty, "Offline registration data should be deleted after global logout")
    }

    func test_performGlobalLogout_deletesFailedLoginAttempts() async throws {
        let (sut, _, _, _, _, failedAttemptsStore) = makeSUT()
        let testEvent = FailedLoginAttemptEvent(email: "test@example.com", timestamp: Date())

        try await failedAttemptsStore.save(event: testEvent)
        let savedAttempts = try await failedAttemptsStore.loadAll()
        XCTAssertFalse(savedAttempts.isEmpty, "Failed login attempts should be saved before logout")

        try await sut.performGlobalLogout()

        let deletedAttempts = try await failedAttemptsStore.loadAll()
        XCTAssertTrue(deletedAttempts.isEmpty, "Failed login attempts should be deleted after global logout")
    }

    func test_performGlobalLogout_deletesAllStorageSimultaneously() async throws {
        let (sut, keychainStore, userDefaults, offlineLoginStore, offlineRegistrationStore, failedAttemptsStore) = makeSUT()

        let testToken = Token(accessToken: "test-token", expiry: Date().addingTimeInterval(3600), refreshToken: "refresh")
        let testCredentials = LoginCredentials(email: "test@example.com", password: "password")
        let testRegistrationData = UserRegistrationData(name: "Test", email: "test@example.com", password: "password")
        let testFailedAttempt = FailedLoginAttemptEvent(email: "test@example.com", timestamp: Date())
        let testUserDefaultsKey = "session-test-key"

        try await keychainStore.save(tokenBundle: testToken)
        try await offlineLoginStore.save(credentials: testCredentials)
        try await offlineRegistrationStore.save(userData: testRegistrationData)
        try await failedAttemptsStore.save(event: testFailedAttempt)
        userDefaults.set("test-value", forKey: testUserDefaultsKey)

        await XCTAssertNotNil(try keychainStore.loadTokenBundle(), "Token should exist before logout")
        await XCTAssertFalse(try (offlineLoginStore.loadAll()).isEmpty, "Offline login data should exist before logout")
        await XCTAssertFalse(try (offlineRegistrationStore.loadAll()).isEmpty, "Offline registration data should exist before logout")
        await XCTAssertFalse(try (failedAttemptsStore.loadAll()).isEmpty, "Failed attempts should exist before logout")
        XCTAssertNotNil(userDefaults.string(forKey: testUserDefaultsKey), "UserDefaults data should exist before logout")

        try await sut.performGlobalLogout()

        await XCTAssertNil(try keychainStore.loadTokenBundle(), "Token should be deleted after logout")
        await XCTAssertTrue(try (offlineLoginStore.loadAll()).isEmpty, "Offline login data should be deleted after logout")
        await XCTAssertTrue(try (offlineRegistrationStore.loadAll()).isEmpty, "Offline registration data should be deleted after logout")
        await XCTAssertTrue(try (failedAttemptsStore.loadAll()).isEmpty, "Failed attempts should be deleted after logout")
        XCTAssertNil(userDefaults.string(forKey: testUserDefaultsKey), "UserDefaults data should be deleted after logout")
    }

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: GlobalLogoutManager,
        keychainStore: KeychainTokenStore,
        userDefaults: UserDefaults,
        offlineLoginStore: InMemoryOfflineLoginStore,
        offlineRegistrationStore: InMemoryOfflineRegistrationStore,
        failedAttemptsStore: InMemoryFailedLoginAttemptsStore
    ) {
        let testSuiteName = "GlobalLogoutIntegrationTest"
        let userDefaults = UserDefaults(suiteName: testSuiteName)!
        let keychainHelper = KeychainHelper()
        let encryptor = AES256CryptoKitEncryptor()
        let keychainStore = KeychainTokenStore(keychainHelper: keychainHelper, encryptor: encryptor)
        let offlineLoginStore = InMemoryOfflineLoginStore()
        let offlineRegistrationStore = InMemoryOfflineRegistrationStore()
        let failedAttemptsStore = InMemoryFailedLoginAttemptsStore()
        let sessionUserDefaults = SessionUserDefaultsManager(userDefaults: userDefaults)

        let sut = GlobalLogoutManager(
            tokenStorage: keychainStore,
            offlineLoginStore: offlineLoginStore,
            offlineRegistrationStore: offlineRegistrationStore,
            failedLoginAttemptsStore: failedAttemptsStore,
            sessionUserDefaults: sessionUserDefaults
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(keychainStore, file: file, line: line)
        trackForMemoryLeaks(offlineLoginStore, file: file, line: line)
        trackForMemoryLeaks(offlineRegistrationStore, file: file, line: line)
        trackForMemoryLeaks(failedAttemptsStore, file: file, line: line)
        trackForMemoryLeaks(sessionUserDefaults, file: file, line: line)

        return (sut, keychainStore, userDefaults, offlineLoginStore, offlineRegistrationStore, failedAttemptsStore)
    }

    private func cleanupTestData() {
        let testSuiteName = "GlobalLogoutIntegrationTest"
        UserDefaults(suiteName: testSuiteName)?.removePersistentDomain(forName: testSuiteName)

        let keychainHelper = KeychainHelper()
        try? keychainHelper.delete(forKey: "token_bundle")
    }
}
