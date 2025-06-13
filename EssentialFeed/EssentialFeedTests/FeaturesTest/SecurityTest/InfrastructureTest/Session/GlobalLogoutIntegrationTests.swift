import EssentialFeed
import XCTest

final class GlobalLogoutIntegrationTests: XCTestCase {
    func test_globalLogout_clearsTokenStorage() async throws {
        let (sut, tokenStorage, _, _, _, _) = makeSUT()

        try await sut.performGlobalLogout()

        let messages = await tokenStorage.messages
        XCTAssertEqual(messages, [.deleteTokenBundle], "Expected to delete token bundle on global logout")
    }

    func test_globalLogout_clearsOfflineLoginStore() async throws {
        let (sut, _, offlineLoginStore, _, _, _) = makeSUT()

        try await sut.performGlobalLogout()

        XCTAssertTrue(offlineLoginStore.messages.contains(.clearAll), "Expected to clear offline login store on global logout")
    }

    func test_globalLogout_clearsOfflineRegistrationStore() async throws {
        let (sut, _, _, offlineRegistrationStore, _, _) = makeSUT()

        try await sut.performGlobalLogout()

        XCTAssertTrue(offlineRegistrationStore.messages.contains(.clearAll), "Expected to clear offline registration store on global logout")
    }

    func test_globalLogout_clearsFailedLoginAttemptsStore() async throws {
        let (sut, _, _, _, failedLoginAttemptsStore, _) = makeSUT()

        try await sut.performGlobalLogout()

        XCTAssertTrue(failedLoginAttemptsStore.messages.contains(.clearAll), "Expected to clear failed login attempts store on global logout")
    }

    func test_globalLogout_clearsSessionUserDefaults() async throws {
        let (sut, _, _, _, _, sessionUserDefaults) = makeSUT()

        try await sut.performGlobalLogout()

        XCTAssertTrue(sessionUserDefaults.messages.contains(.clearSessionData), "Expected to clear session UserDefaults on global logout")
    }

    func test_globalLogout_propagatesErrorFromTokenStorage() async {
        let (sut, tokenStorage, _, _, _, _) = makeSUT()
        let expectedError = anyNSError()
        await tokenStorage.completeDeleteTokenBundle(withError: expectedError)

        do {
            try await sut.performGlobalLogout()
            XCTFail("Expected an error to be thrown from token storage")
        } catch {
            XCTAssertEqual(error as NSError, expectedError, "Expected to propagate error from token storage")
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: GlobalLogoutManager,
        tokenStorage: TokenStorageSpy,
        offlineLoginStore: OfflineLoginStoreSpy,
        offlineRegistrationStore: OfflineRegistrationStoreSpy,
        failedLoginAttemptsStore: FailedLoginAttemptsStoreSpy,
        sessionUserDefaults: SessionUserDefaultsSpy
    ) {
        let tokenStorageSpy = TokenStorageSpy()
        let offlineLoginStoreSpy = OfflineLoginStoreSpy()
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

        return (sut, tokenStorageSpy, offlineLoginStoreSpy, offlineRegistrationStoreSpy, failedLoginAttemptsStoreSpy, sessionUserDefaultsSpy)
    }

    private func anyNSError() -> NSError {
        NSError(domain: "any error", code: 0)
    }
}
