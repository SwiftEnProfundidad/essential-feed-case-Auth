import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class PasswordRecoverySnapshotTests: XCTestCase {
    func test_passwordRecovery_success_light() {
        let response = PasswordRecoveryResponse(message: "Recovery email sent!")
        let sut = makeSUT(email: "user@email.com", apiResult: .success(response))
        assert(snapshot: sut.snapshot(for: .iPhone13(style: .light)), named: "PASSWORD_RECOVERY_SUCCESS_light")
    }

    func test_passwordRecovery_error_dark() {
        let sut = makeSUT(email: "user@email.com", apiResult: .failure(.emailNotFound))
        assert(snapshot: sut.snapshot(for: .iPhone13(style: .dark)), named: "PASSWORD_RECOVERY_ERROR_dark")
    }

    // MARK: - Helpers

    private func makeSUT(email: String, apiResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> UIViewController {
        let api = DummyPasswordRecoveryAPI(result: apiResult)
        let useCase = RemoteUserPasswordRecoveryUseCase(api: api)
        let viewModel = PasswordRecoverySwiftUIViewModel(recoveryUseCase: useCase)
        viewModel.email = email
        let view = PasswordRecoveryScreen(viewModel: viewModel)
        let controller = UIHostingController(rootView: view)
        controller.loadViewIfNeeded()
        // Simula la acción de recuperación
        viewModel.recoverPassword()
        return controller
    }
}

private final class DummyPasswordRecoveryAPI: PasswordRecoveryAPI {
    private let result: Result<PasswordRecoveryResponse, PasswordRecoveryError>
    init(result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        self.result = result
    }

    func recover(email _: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        completion(result)
    }
}
