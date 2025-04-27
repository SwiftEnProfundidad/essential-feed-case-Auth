import Foundation

public final class PasswordRecoveryPresenter {
    private let view: PasswordRecoveryView

    public init(view: PasswordRecoveryView) {
        self.view = view
    }

    public func didRecoverPassword(with result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        switch result {
        case let .success(response):
            view.display(PasswordRecoveryViewModel(message: response.message, isSuccess: true))
        case let .failure(error):
            let message: String
            switch error {
            case .invalidEmailFormat:
                message = "El email no tiene un formato válido."
            case .emailNotFound:
                message = "No existe ninguna cuenta asociada a ese email."
            case .network:
                message = "Error de conexión. Inténtalo de nuevo."
            }
            view.display(PasswordRecoveryViewModel(message: message, isSuccess: false))
        }
    }
}
