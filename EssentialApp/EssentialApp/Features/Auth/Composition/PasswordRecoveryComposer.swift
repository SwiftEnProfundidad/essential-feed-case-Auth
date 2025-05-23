
import EssentialFeed
import SwiftUI
import UIKit

public enum PasswordRecoveryComposer {
    public static func passwordRecoveryViewScreen() -> PasswordRecoveryScreen {
        // TODO: Inyecta tu API real aquí
        let apiStub = PasswordRecoveryAPIStub(result: .success(PasswordRecoveryResponse(message: "Simulación de recuperación")))
        let recoveryUseCase = RemoteUserPasswordRecoveryUseCase(api: apiStub)
        let viewModel = PasswordRecoverySwiftUIViewModel(recoveryUseCase: recoveryUseCase)
        let presenter = PasswordRecoveryPresenter(view: viewModel)
        viewModel.setPresenter(presenter)
        let recoveryView = PasswordRecoveryScreen(viewModel: viewModel)
        return recoveryView
    }
}

// MARK: - Stub para desarrollo

private class PasswordRecoveryAPIStub: PasswordRecoveryAPI {
    private let result: Result<PasswordRecoveryResponse, PasswordRecoveryError>
    init(result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        self.result = result
    }

    func recover(email _: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        completion(result)
    }
}
