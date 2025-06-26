import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class LoginNotificationSnapshotTests: XCTestCase {
    func test_loginSuccess_showsSuccessNotification() async {
        let sut = makeSUT(authenticate: { _, _ in
            .success(
                LoginResponse(
                    user: User(name: "Test User", email: "test@example.com"),
                    token: Token(
                        accessToken: "dummy_token", expiry: Date().addingTimeInterval(3600), refreshToken: nil
                    )
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
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]
        for language in languages {
            for (uiStyle, schemeName) in schemes {
                let locale = Locale(identifier: language)
                let sut = makeSUT(authenticate: sut.viewModel.authenticate, locale: locale)
                await MainActor.run {
                    sut.controller.overrideUserInterfaceStyle = uiStyle
                    sut.controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                    sut.controller.view.window?.overrideUserInterfaceStyle = uiStyle
                    sut.controller.view.window?.rootViewController?.overrideUserInterfaceStyle = uiStyle
                    sut.controller.view.window?.rootViewController?.view.setNeedsLayout()
                    sut.controller.view.window?.rootViewController?.view.layoutIfNeeded()
                }
                let snapshot = sut.snapshot(for: .iPhone13(style: uiStyle, locale: locale))
                assert(
                    snapshot: snapshot, named: name, language: language, scheme: schemeName, file: file,
                    line: line
                )
            }
        }
    }

    private func makeSUT(
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>,
        locale: Locale = .current,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> LoginTestHarness {
        let sut = LoginTestHarness(authenticate: authenticate, locale: locale)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
}

final class LoginTestHarness {
    let viewModel: LoginViewModel
    let controller: UIHostingController<AnyView>

    init(authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>, locale: Locale = .current) {
        let viewModel = LoginViewModel(authenticate: authenticate)
        self.viewModel = viewModel
        let rootView = AnyView(LoginView(viewModel: viewModel).environment(\.locale, locale))
        if !Thread.isMainThread {
            var controller: UIHostingController<AnyView>!
            DispatchQueue.main.sync {
                controller = UIHostingController(rootView: rootView)
                controller.loadViewIfNeeded()
            }
            self.controller = controller
        } else {
            self.controller = UIHostingController(rootView: rootView)
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
