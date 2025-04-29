import XCTest
import SwiftUI
import EssentialApp
import EssentialFeed

final class LoginIntegrationSnapshotTests: XCTestCase {
	func test_loginSuccess_showsSuccessNotification() async {
		let sut = makeSUT(authenticate: { _, _ in
				.success(LoginResponse(token: "dummy_token"))
		})
		sut.simulateUserEntering(username: "user", password: "pass")
		await sut.simulateTapOnLoginButton()
		sut.waitForLoginSuccessAlert()
		assert(snapshot: sut.snapshot(for: .iPhone13(style: .light)), named: "LOGIN_SUCCESS_NOTIFICATION_light")
	}
	
	func test_loginError_showsErrorNotification() async {
		let sut = makeSUT(authenticate: { _, _ in
				.failure(.invalidCredentials)
		})
		sut.simulateUserEntering(username: "user", password: "wrongpass")
		await sut.simulateTapOnLoginButton()
		sut.waitForLoginSuccessAlert()
		assert(snapshot: sut.snapshot(for: .iPhone13(style: .light)), named: "LOGIN_ERROR_NOTIFICATION_light")
	}
	
	// MARK: Helpers
	
	private func makeSUT(authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>) -> LoginTestHarness {
		LoginTestHarness(authenticate: authenticate)
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
