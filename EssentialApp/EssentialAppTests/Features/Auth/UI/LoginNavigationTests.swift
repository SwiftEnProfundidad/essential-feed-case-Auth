import EssentialApp
import EssentialFeed
import XCTest

final class LoginNavigationTests: XCTestCase {
    func test_registerButtonTap_triggersRegistrationNavigation() {
        let (sut, navigationSpy) = makeSUT()

        sut.handleRegisterTap()

        XCTAssertTrue(navigationSpy.didShowRegister, "Should show register screen after register button tap")
    }

    func test_recoveryButtonTap_triggersRecoveryNavigation() {
        let (sut, navigationSpy) = makeSUT()

        sut.handleRecoveryTap()

        XCTAssertTrue(navigationSpy.didShowRecovery, "Should show recovery screen after recovery button tap")
    }

    func test_bothNavigationCallbacks_canBeTriggeredIndependently() {
        let (sut, navigationSpy) = makeSUT()

        sut.handleRegisterTap()
        XCTAssertTrue(navigationSpy.didShowRegister, "Should show register screen")

        sut.handleRecoveryTap()
        XCTAssertTrue(navigationSpy.didShowRecovery, "Should show recovery screen")
        XCTAssertTrue(navigationSpy.didShowRegister, "Should not affect previous register navigation")
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
    ) -> (sut: LoginViewModel, navigationSpy: LoginNavigationSpy) {
        let navigationSpy = LoginNavigationSpy()
        let configuration = LoginSecurityConfiguration(
            maxAttempts: 3,
            blockDuration: 300,
            captchaThreshold: 2
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
        sut.navigation = navigationSpy

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(navigationSpy, file: file, line: line)

        return (sut, navigationSpy)
    }
}

private final class LoginNavigationSpy: LoginNavigation {
    private(set) var didShowRecovery = false
    private(set) var didShowRegister = false

    func showRecovery() {
        didShowRecovery = true
    }

    func showRegister() {
        didShowRegister = true
    }
}
