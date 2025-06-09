import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class LoginIntegrationSnapshotTests: XCTestCase {
    func test_loginSuccess_showsSuccessNotification() async {
        let sut = makeSUT(authenticate: { _, _ in
            .success(LoginResponse(token: "dummy_token"))
        })
        await verifySnapshot(
            for: sut,
            action: { sut in
                sut.simulateUserEntering(username: "user", password: "pass")
                await sut.simulateTapOnLoginButton()
                sut.waitForLoginSuccessAlert()
            },
            named: "LOGIN_SUCCESS_NOTIFICATION"
        )
    }

    func test_loginError_showsErrorNotification() async {
        let sut = makeSUT(authenticate: { _, _ in
            .failure(.invalidCredentials)
        })
        await verifySnapshot(
            for: sut,
            action: { sut in
                sut.simulateUserEntering(username: "user", password: "wrongpass")
                await sut.simulateTapOnLoginButton()
                sut.waitForLoginSuccessAlert()
            },
            named: "LOGIN_ERROR_NOTIFICATION"
        )
    }

    func test_loginNetworkError_showsNetworkErrorNotification() async {
        let sut = makeSUT(authenticate: { _, _ in
            .failure(.network)
        })
        await verifySnapshot(
            for: sut,
            action: { sut in
                sut.simulateUserEntering(username: "user", password: "pass")
                await sut.simulateTapOnLoginButton()
                sut.waitForLoginSuccessAlert()
            },
            named: "LOGIN_NETWORK_ERROR_NOTIFICATION"
        )
    }

    func test_loginUnknownError_showsGenericErrorNotification() async {
        let sut = makeSUT(authenticate: { _, _ in
            .failure(.unknown)
        })
        await verifySnapshot(
            for: sut,
            action: { sut in
                sut.simulateUserEntering(username: "user", password: "pass")
                await sut.simulateTapOnLoginButton()
                sut.waitForLoginSuccessAlert()
            },
            named: "LOGIN_UNKNOWN_ERROR_NOTIFICATION"
        )
    }

    func test_loginWithValidCredentials_integratesFullChain_andNotifiesSuccessObserver() async {
        let (sut, successObserver, apiSpy) = makeIntegrationSUT()

        // Setup API spy para devolver success
        apiSpy.stubbedResult = Result<LoginResponse, LoginError>.success(LoginResponse(token: "expected_token"))

        sut.simulateUserEntering(username: "valid@email.com", password: "validpass123")
        await sut.simulateTapOnLoginButton()

        // Verify real integration chain worked
        XCTAssertEqual(successObserver.notificationCount, 1, "Should notify success observer")
        XCTAssertNotNil(successObserver.lastResponse, "Should receive login response")
        XCTAssertEqual(successObserver.lastResponse?.token, "expected_token", "Should receive correct token")
    }

    // MARK: - Helpers

    private func verifySnapshot(
        for sut: LoginTestHarness,
        action: (LoginTestHarness) async -> Void,
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await action(sut)

        let lightSnapshot = sut.snapshot(for: .iPhone13(style: .light))
        let darkSnapshot = sut.snapshot(for: .iPhone13(style: .dark))

        assert(snapshot: lightSnapshot, named: "\(name)_light", file: file, line: line)
        assert(snapshot: darkSnapshot, named: "\(name)_dark", file: file, line: line)
    }

    private func makeSUT(
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> LoginTestHarness {
        let sut = LoginTestHarness(authenticate: authenticate)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private func makeIntegrationSUT() -> (LoginTestHarness, LoginSuccessObserverSpy, UserLoginAPISpy) {
        let validator = LoginCredentialsValidator()

        let failedLoginStore = InMemoryFailedLoginAttemptsStore()
        let securityUseCase = LoginSecurityUseCase(
            store: failedLoginStore,
            maxAttempts: 3,
            blockDuration: 300
        )

        let api = UserLoginAPISpy()
        let tokenStorage = TokenStorageSpy()
        let offlineStore = OfflineLoginStoreSpy()
        let config = UserLoginConfiguration(maxFailedAttempts: 3, lockoutDuration: 300, tokenDuration: 3600)

        let persistence = LoginPersistenceSpy(tokenStorage: tokenStorage, offlineStore: offlineStore, config: config)

        let loginService = DefaultLoginService(
            validator: validator,
            securityUseCase: securityUseCase,
            api: api,
            persistence: persistence,
            config: config
        )

        let useCase = UserLoginUseCase(loginService: loginService)
        let successObserver = LoginSuccessObserverSpy()
        let failureObserver = LoginFailureObserverSpy()

        let notifier = LoginEventNotifierSpy(successObserver: successObserver, failureObserver: failureObserver)
        let flowHandler = LoginFlowHandlerSpy()

        let presenter = LoginPresenter(
            useCase: useCase,
            notifier: notifier,
            flowHandler: flowHandler
        )

        let sut = LoginTestHarness(presenter: presenter)

        return (sut, successObserver, api)
    }
}

// MARK: - In Memory Failed Login Store for Tests

private final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsStore {
    private var attempts: [String: Int] = [:]
    private var lastAttemptTimes: [String: Date] = [:]

    func getAttempts(for username: String) -> Int {
        attempts[username] ?? 0
    }

    func incrementAttempts(for username: String) async {
        attempts[username] = getAttempts(for: username) + 1
        lastAttemptTimes[username] = Date()
    }

    func resetAttempts(for username: String) async {
        attempts[username] = 0
        lastAttemptTimes[username] = nil
    }

    func lastAttemptTime(for username: String) -> Date? {
        lastAttemptTimes[username]
    }
}

final class LoginTestHarness {
    let viewModel: LoginViewModel
    let controller: UIHostingController<LoginView>

    init(authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>) {
        let viewModel = LoginViewModel(authenticate: authenticate)
        self.viewModel = viewModel
        if !Thread.isMainThread {
            var controller: UIHostingController<LoginView>!
            DispatchQueue.main.sync {
                controller = UIHostingController(rootView: LoginView(viewModel: viewModel))
                controller.loadViewIfNeeded()
            }
            self.controller = controller
        } else {
            self.controller = UIHostingController(rootView: LoginView(viewModel: viewModel))
            controller.loadViewIfNeeded()
        }
    }

    convenience init(presenter: LoginPresenter) {
        let authenticateWrapper: (String, String) async -> Result<LoginResponse, LoginError> = { username, password in
            let credentials = LoginCredentials(email: username, password: password)
            await presenter.login(with: credentials)
            return .success(LoginResponse(token: "integration_token"))
        }

        self.init(authenticate: authenticateWrapper)
    }

    func simulateUserEntering(username: String, password: String) {
        viewModel.username = username
        viewModel.password = password
    }

    func simulateTapOnLoginButton() async {
        await viewModel.login()
    }

    func waitForLoginSuccessAlert(timeout: TimeInterval = 0.5) {
        let exp = XCTestExpectation(description: "Wait for login success alert")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            exp.fulfill()
        }
        _ = XCTWaiter.wait(for: [exp], timeout: timeout)
    }

    func snapshot(for configuration: SnapshotConfiguration) -> UIImage {
        controller.snapshot(for: configuration)
    }
}
