import UIKit
import SwiftUI
import EssentialFeed

public enum PasswordRecoveryComposer {
    public static func passwordRecoveryViewScreen() -> PasswordRecoveryScreen {
        // TODO: Inyecta tu API real aquí
        let apiStub = PasswordRecoveryAPIStub(result: .success(PasswordRecoveryResponse(message: "Simulación de recuperación")))
        let recoveryUseCase = UserPasswordRecoveryUseCase(api: apiStub)
        let viewModel = PasswordRecoverySwiftUIViewModel(recoveryUseCase: recoveryUseCase)
        let recoveryView = PasswordRecoveryScreen(viewModel: viewModel)
        return recoveryView
    }
}

// Stub para desarrollo
private class PasswordRecoveryAPIStub: PasswordRecoveryAPI {
    private let result: Result<PasswordRecoveryResponse, PasswordRecoveryError>
    init(result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        self.result = result
    }
    func recover(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        completion(result)
    }
}
