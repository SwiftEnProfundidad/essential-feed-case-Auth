import EssentialFeed
import XCTest

final class GlobalLogoutIntegrationTests: XCTestCase {
    func test_globalLogout_clearsAllCredentials() async throws {
        let (sut, tokenStorage) = makeSUT()

        do {
            try await sut.performGlobalLogout()
        } catch {
            XCTFail("Should not fail to clear credentials, got error: \(error)")
        }

        let tokenStorageMessages = await tokenStorage.messages
        XCTAssertEqual(tokenStorageMessages, [.deleteTokenBundle], "Should clear stored tokens")
    }

    func test_globalLogout_doesNotFailOnEmptyCredentials() async throws {
        let (sut, tokenStorage) = makeSUT()

        await tokenStorage.completeDeleteTokenBundleSuccessfully()

        do {
            try await sut.performGlobalLogout()
        } catch {
            XCTFail("Should not fail on empty credentials, got error: \(error)")
        }
    }

    func test_globalLogout_handlesTokenStorageFailure() async throws {
        let (sut, tokenStorage) = makeSUT()

        await tokenStorage.completeDeleteTokenBundle(withError: anyNSError())

        do {
            try await sut.performGlobalLogout()
            XCTFail("Should fail when token storage fails")
        } catch {
            XCTAssertNotNil(error, "Should receive an error when token storage fails")
        }

        let tokenStorageMessages = await tokenStorage.messages
        XCTAssertEqual(tokenStorageMessages, [.deleteTokenBundle], "Should attempt to clear tokens")
    }

    func test_globalLogout_clearsOfflineCredentials() async throws {
        let offlineRegistrationStore = OfflineRegistrationStoreSpy()
        let offlineLoginStore = OfflineLoginStoreSpy()
        let failedLoginAttemptsStore = FailedLoginAttemptsStoreSpy()
        let sessionUserDefaults = SessionUserDefaultsSpy()
        let tokenStorage = TokenStorageSpy()

        let sut = GlobalLogoutManager(
            tokenStorage: tokenStorage,
            offlineLoginStore: offlineLoginStore,
            offlineRegistrationStore: offlineRegistrationStore,
            failedLoginAttemptsStore: failedLoginAttemptsStore,
            sessionUserDefaults: sessionUserDefaults
        )

        do {
            try await sut.performGlobalLogout()
        } catch {
            XCTFail("Should succeed in clearing offline credentials, got error: \(error)")
        }

        let offlineStoreMessages = offlineRegistrationStore.messages
        XCTAssertTrue(offlineStoreMessages.contains(.clearAll), "Should clear offline registration data")

        let tokenStorageMessages = await tokenStorage.messages
        XCTAssertEqual(tokenStorageMessages, [.deleteTokenBundle], "Should clear stored tokens")
    }

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: GlobalLogoutManager, tokenStorage: TokenStorageSpy) {
        let tokenStorage = TokenStorageSpy()
        let offlineRegistrationStore = OfflineRegistrationStoreSpy()
        let offlineLoginStore = OfflineLoginStoreSpy()
        let failedLoginAttemptsStore = FailedLoginAttemptsStoreSpy()
        let sessionUserDefaults = SessionUserDefaultsSpy()

        let sut = GlobalLogoutManager(
            tokenStorage: tokenStorage,
            offlineLoginStore: offlineLoginStore,
            offlineRegistrationStore: offlineRegistrationStore,
            failedLoginAttemptsStore: failedLoginAttemptsStore,
            sessionUserDefaults: sessionUserDefaults
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(tokenStorage, file: file, line: line)
        trackForMemoryLeaks(offlineRegistrationStore, file: file, line: line)
        trackForMemoryLeaks(offlineLoginStore, file: file, line: line)
        trackForMemoryLeaks(failedLoginAttemptsStore, file: file, line: line)
        trackForMemoryLeaks(sessionUserDefaults, file: file, line: line)

        return (sut, tokenStorage)
    }

    private func anyNSError() -> NSError {
        NSError(domain: "any error", code: 0)
    }
}
