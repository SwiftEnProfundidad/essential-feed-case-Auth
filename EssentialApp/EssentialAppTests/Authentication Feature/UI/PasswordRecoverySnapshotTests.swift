import XCTest
import SwiftUI
@testable import EssentialApp

final class PasswordRecoverySnapshotTests: XCTestCase {
    func test_passwordRecovery_light() {
        let sut = makeSUT(email: "")
        assert(snapshot: sut.snapshot(for: .iPhone13(style: .light)), named: "PASSWORD_RECOVERY_light")
    }

    func test_passwordRecovery_dark() {
        let sut = makeSUT(email: "user@email.com")
        assert(snapshot: sut.snapshot(for: .iPhone13(style: .dark)), named: "PASSWORD_RECOVERY_dark")
    }

    func test_passwordRecovery_accessibility() {
        let sut = makeSUT(email: "accesibility@email.com")
        // Puedes extender SnapshotConfiguration para soportar contentSize: .extraExtraExtraLarge
        assert(snapshot: sut.snapshot(for: .iPhone13(style: .light)), named: "PASSWORD_RECOVERY_light_extraExtraExtraLarge")
    }

    // MARK: - Helpers

    private func makeSUT(email: String) -> UIViewController {
        let viewModel = PasswordRecoverySwiftUIViewModel.mock(email: email)
        let view = PasswordRecoveryScreen(viewModel: viewModel)
        let controller = UIHostingController(rootView: view)
        controller.loadViewIfNeeded()
        return controller
    }
}

private extension PasswordRecoverySwiftUIViewModel {
    static func mock(email: String) -> PasswordRecoverySwiftUIViewModel {
        let mock = PasswordRecoverySwiftUIViewModel(recoveryUseCase: DummyRecoveryUseCase())
        mock.email = email
        return mock
    }
}

private class DummyRecoveryUseCase: UserPasswordRecoveryUseCase {
    func recoverPassword(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {}
}
