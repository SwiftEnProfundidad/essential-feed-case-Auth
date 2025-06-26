import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class LoginNotificationSnapshotTests: XCTestCase {
    func test_loginSuccess_showsSuccessNotification() async {
        let sut = makeSUT(authenticate: { _, _ in
            .success(LoginResponse(
                user: User(name: "Test User", email: "test@example.com"),
                token: Token(accessToken: "dummy_token", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
            ))
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
