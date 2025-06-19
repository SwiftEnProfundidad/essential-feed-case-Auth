import EssentialApp
import EssentialFeed
import XCTest

final class LoginNavigationTests: XCTestCase {
    func test_registerButtonTap_triggersRegistrationNavigation() async {
        let (sut, navigationSpy) = makeSUT()

        XCTAssertFalse(navigationSpy.registerScreenShown, "Should not show register screen initially")

        sut.handleRegisterTap()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(navigationSpy.registerScreenShown, "Should show register screen after register button tap")
        XCTAssertFalse(navigationSpy.recoveryScreenShown, "Should not show recovery screen when register is tapped")
    }

    func test_recoveryButtonTap_triggersRecoveryNavigation() async {
        let (sut, navigationSpy) = makeSUT()

        XCTAssertFalse(navigationSpy.recoveryScreenShown, "Should not show recovery screen initially")

        sut.handleRecoveryTap()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(navigationSpy.recoveryScreenShown, "Should show recovery screen after recovery button tap")
        XCTAssertFalse(navigationSpy.registerScreenShown, "Should not show register screen when recovery is tapped")
    }

    func test_bothNavigationCallbacks_canBeTriggeredIndependently() async {
        let (sut, navigationSpy) = makeSUT()

        sut.handleRegisterTap()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(navigationSpy.registerScreenShown, "Should show register screen")
        XCTAssertFalse(navigationSpy.recoveryScreenShown, "Should not affect recovery screen")

        sut.handleRecoveryTap()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(navigationSpy.recoveryScreenShown, "Should show recovery screen")
        XCTAssertTrue(navigationSpy.registerScreenShown, "Should not affect previous register navigation")
    }

    func test_registerRequested_publisherSendsEvent() async {
        let (sut, _) = makeSUT()
        var registerEventReceived = false
        let expectation = XCTestExpectation(description: "Register event should be received")

        let cancellable = sut.registerRequested.sink { _ in
            registerEventReceived = true
            expectation.fulfill()
        }

        sut.handleRegisterTap()

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(registerEventReceived, "Should send register event through publisher")
        _ = cancellable
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #file,
        line: UInt = #line
    ) -> (sut: LoginViewModel, spy: NavigationSpy) {
        let configuration = LoginSecurityConfiguration(
            maxAttempts: 3,
            blockDuration: 300,
            captchaThreshold: 2 // <<< ASEGÚRATE QUE ESTA LÍNEA ESTÉ ASÍ
        )
        let loginSecurity = LoginSecurityUseCase(
            store: ThreadSafeFailedLoginAttemptsStoreSpy(),
            configuration: configuration
        )
        let sut = LoginViewModel(
            authenticate: { _, _ in .failure(.invalidCredentials) },
            loginSecurity: loginSecurity,
            blockMessageProvider: DefaultLoginBlockMessageProvider()
        )
        let navigationSpy = NavigationSpy()
        sut.navigation = navigationSpy

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(navigationSpy, file: file, line: line)
        return (sut, navigationSpy)
    }

    private class NavigationSpy: LoginNavigation {
        private(set) var recoveryScreenShown = false
        private(set) var registerScreenShown = false

        func showRecovery() {
            recoveryScreenShown = true
        }

        func showRegister() {
            registerScreenShown = true
        }
    }
}
