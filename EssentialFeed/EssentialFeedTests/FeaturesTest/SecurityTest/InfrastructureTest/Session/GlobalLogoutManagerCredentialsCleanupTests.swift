import EssentialFeed
import XCTest

final class GlobalLogoutManagerCredentialsCleanupTests: XCTestCase {
    func test_performGlobalLogout_deletesTokenBundle() async throws {
        let (sut, spies) = makeSUT()

        try await sut.performGlobalLogout()

        let tokenStorageMessages = await spies.tokenStorage.messages
        XCTAssertTrue(tokenStorageMessages.contains(.deleteTokenBundle), "Should delete token bundle from secure storage")
    }

    func test_performGlobalLogout_whenTokenStorageFails_propagatesError() async {
        let (sut, spies) = makeSUT()
        let expectedError = NSError(domain: "test", code: 0)
        await spies.tokenStorage.completeDeleteTokenBundle(withError: expectedError)

        do {
            try await sut.performGlobalLogout()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, expectedError, "Should propagate token storage error")
        }
    }

    func test_performGlobalLogout_clearsOfflineLoginStore() async throws {
        let (sut, spies) = makeSUT()

        try await sut.performGlobalLogout()

        XCTAssertTrue(spies.offlineLoginStore.messages.contains(.clearAll), "Should send a .clearAll message to offlineLoginStore")
    }

    func test_performGlobalLogout_whenOfflineLoginStoreFails_propagatesError() async {
        let (sut, spies) = makeSUT()
        let expectedError = NSError(domain: "test", code: 1)
        spies.offlineLoginStore.clearAllError = expectedError

        do {
            try await sut.performGlobalLogout()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, expectedError, "Should propagate offline store error")
        }
    }

    func test_performGlobalLogout_clearsOfflineRegistrationStore() async throws {
        let (sut, spies) = makeSUT()

        try await sut.performGlobalLogout()

        XCTAssertEqual(spies.offlineRegistrationStore.messages.contains(.clearAll), true, "Should clear offline registration store")
    }

    func test_performGlobalLogout_whenOfflineRegistrationStoreFails_propagatesError() async {
        let (sut, spies) = makeSUT()
        let expectedError = NSError(domain: "test", code: 2)
        spies.offlineRegistrationStore.clearAllError = expectedError

        do {
            try await sut.performGlobalLogout()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, expectedError, "Should propagate offline registration store error")
        }
    }

    func test_performGlobalLogout_clearsFailedLoginAttemptsStore() async throws {
        let (sut, spies) = makeSUT()

        try await sut.performGlobalLogout()

        XCTAssertEqual(spies.failedLoginAttemptsStore.messages.contains(.clearAll), true, "Should clear failed login attempts store")
    }

    func test_performGlobalLogout_whenFailedLoginAttemptsStoreFails_propagatesError() async {
        let (sut, spies) = makeSUT()
        let expectedError = NSError(domain: "test", code: 3)
        spies.failedLoginAttemptsStore.clearAllError = expectedError

        do {
            try await sut.performGlobalLogout()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, expectedError, "Should propagate failed login attempts store error")
        }
    }

    func test_performGlobalLogout_clearsSessionUserDefaults() async throws {
        let (sut, spies) = makeSUT()

        try await sut.performGlobalLogout()

        XCTAssertEqual(spies.sessionUserDefaults.messages.contains(.clearSessionData), true, "Should clear session UserDefaults")
    }

    func test_performGlobalLogout_whenSessionUserDefaultsFails_propagatesError() async {
        let (sut, spies) = makeSUT()
        let expectedError = NSError(domain: "test", code: 4)
        spies.sessionUserDefaults.clearSessionDataError = expectedError

        do {
            try await sut.performGlobalLogout()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as NSError, expectedError, "Should propagate session UserDefaults error")
        }
    }

    func test_performGlobalLogout_clearsAllStoresInCorrectOrder() async throws {
        let (sut, spies) = makeSUT()

        try await sut.performGlobalLogout()

        let tokenStorageMessages = await spies.tokenStorage.messages
        XCTAssertTrue(tokenStorageMessages.contains(.deleteTokenBundle), "Should delete token bundle")
        XCTAssertTrue(spies.offlineLoginStore.messages.contains(.clearAll), "Should clear offline login store")
        XCTAssertTrue(spies.offlineRegistrationStore.messages.contains(.clearAll), "Should clear offline registration store")
        XCTAssertTrue(spies.failedLoginAttemptsStore.messages.contains(.clearAll), "Should clear failed login attempts store")
        XCTAssertTrue(spies.sessionUserDefaults.messages.contains(.clearSessionData), "Should clear session UserDefaults")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: GlobalLogoutManager, spies: (tokenStorage: TokenStorageSpy, offlineLoginStore: OfflineLoginStoreSpy, offlineRegistrationStore: OfflineRegistrationStoreSpy, failedLoginAttemptsStore: FailedLoginAttemptsStoreSpy, sessionUserDefaults: SessionUserDefaultsSpy)) {
        let tokenStorageSpy = TokenStorageSpy()
        let offlineLoginStoreSpy = OfflineLoginStoreSpy() // Usará el Spy público y compartido
        let offlineRegistrationStoreSpy = OfflineRegistrationStoreSpy()
        let failedLoginAttemptsStoreSpy = FailedLoginAttemptsStoreSpy()
        let sessionUserDefaultsSpy = SessionUserDefaultsSpy()
        let sut = GlobalLogoutManager(
            tokenStorage: tokenStorageSpy,
            offlineLoginStore: offlineLoginStoreSpy,
            offlineRegistrationStore: offlineRegistrationStoreSpy,
            failedLoginAttemptsStore: failedLoginAttemptsStoreSpy,
            sessionUserDefaults: sessionUserDefaultsSpy
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(tokenStorageSpy, file: file, line: line)
        trackForMemoryLeaks(offlineLoginStoreSpy, file: file, line: line)
        trackForMemoryLeaks(offlineRegistrationStoreSpy, file: file, line: line)
        trackForMemoryLeaks(failedLoginAttemptsStoreSpy, file: file, line: line)
        trackForMemoryLeaks(sessionUserDefaultsSpy, file: file, line: line)

        return (sut, (tokenStorageSpy, offlineLoginStoreSpy, offlineRegistrationStoreSpy, failedLoginAttemptsStoreSpy, sessionUserDefaultsSpy))
    }
}
