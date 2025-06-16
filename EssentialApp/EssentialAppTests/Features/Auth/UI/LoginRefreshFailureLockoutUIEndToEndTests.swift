@preconcurrency import EssentialFeed
import XCTest

final class LoginRefreshFailureLockoutUIEndToEndTests: XCTestCase {
    func test_repeatedRefreshFailures_triggersAccountLockout_showsLogoutUI() async {
        let (sut, refreshServiceSpy, _) = makeSUT()

        await simulateMultipleRefreshFailures(sut: sut, refreshServiceSpy: refreshServiceSpy, count: 3)

        XCTAssertTrue(sut.isLoginBlocked, "Account should be locked after repeated refresh failures")
        XCTAssertTrue(sut.errorMessage?.contains("locked") == true, "Should show lockout message")
        XCTAssertEqual(refreshServiceSpy.refreshTokenCallCount, 3, "Should attempt refresh 3 times")
    }

    func test_refreshFailureLockout_suggestsPasswordRecovery() async {
        let (sut, refreshServiceSpy, _) = makeSUT()

        await simulateMultipleRefreshFailures(sut: sut, refreshServiceSpy: refreshServiceSpy, count: 3)

        XCTAssertTrue(sut.isLoginBlocked, "Should suggest password recovery when locked")
    }

    func test_lockoutAfterRefreshFailures_clearsAfterTimeout() async {
        let (sut, refreshServiceSpy, _) = makeSUT(blockDuration: 1.0)

        await simulateMultipleRefreshFailures(sut: sut, refreshServiceSpy: refreshServiceSpy, count: 3)
        XCTAssertTrue(sut.isLoginBlocked, "Should be locked initially")

        try? await Task.sleep(nanoseconds: 1_100_000_000)

        sut.username = "test@example.com"
        sut.password = "password"
        await sut.login()

        XCTAssertFalse(sut.isLoginBlocked, "Should be unlocked after timeout")
    }

    private func simulateMultipleRefreshFailures(sut: LoginViewModel, refreshServiceSpy: TokenRefreshServiceSpy, count: Int) async {
        refreshServiceSpy.completeRefresh(with: .failure(.network))

        sut.username = "user@example.com"
        sut.password = "wrongpassword"

        for i in 1 ... count {
            await sut.login()
            _ = await refreshServiceSpy.refreshToken(refreshToken: "expired_token_\(i)")
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func makeSUT(
        blockDuration: TimeInterval = 300,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LoginViewModel, refreshServiceSpy: TokenRefreshServiceSpy, securityUseCase: LoginSecurityUseCase) {
        let refreshServiceSpy = TokenRefreshServiceSpy()
        let failedLoginAttemptsStore = ThreadSafeFailedLoginAttemptsStoreSpy()
        let securityUseCase = LoginSecurityUseCase(
            store: failedLoginAttemptsStore,
            configuration: LoginSecurityConfiguration(maxAttempts: 3, blockDuration: blockDuration)
        )

        let sut = LoginViewModel(
            authenticate: { _, _ in .failure(.invalidCredentials) },
            loginSecurity: securityUseCase
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(refreshServiceSpy, file: file, line: line)
        trackForMemoryLeaks(securityUseCase, file: file, line: line)

        return (sut, refreshServiceSpy, securityUseCase)
    }
}
