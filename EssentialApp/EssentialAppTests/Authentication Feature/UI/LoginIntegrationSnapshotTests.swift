import XCTest
import SwiftUI
import EssentialApp
import EssentialFeed

final class LoginIntegrationSnapshotTests: XCTestCase {
    func test_loginSuccess_showsSuccessNotification() {
        let sut = LoginTestHarness()
        sut.simulateUserEntering(username: "user", password: "pass")
        sut.simulateTapOnLoginButton()
        sut.waitForLoginSuccessAlert()
        assert(snapshot: sut.snapshot(for: .iPhone13(style: .light)), named: "LOGIN_SUCCESS_NOTIFICATION_light")
    }
}

final class LoginTestHarness {
    let viewModel: LoginViewModel
    let controller: UIHostingController<LoginView>

    init() {
        self.viewModel = LoginViewModel()
        self.controller = UIHostingController(rootView: LoginView(viewModel: viewModel))
        controller.loadViewIfNeeded()
    }

    func simulateUserEntering(username: String, password: String) {
        viewModel.username = username
        viewModel.password = password
    }

    func simulateTapOnLoginButton() {
        viewModel.login()
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
