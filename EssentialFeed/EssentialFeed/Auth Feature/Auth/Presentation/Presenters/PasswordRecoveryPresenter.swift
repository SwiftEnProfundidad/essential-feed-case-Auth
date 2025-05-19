import Foundation

public final class PasswordRecoveryPresenter {
    private weak var view: PasswordRecoveryView?

    public init(view: PasswordRecoveryView) {
        self.view = view
    }

    public func didRecoverPassword(with result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        switch result {
        case let .success(response):
            view?.display(PasswordRecoveryViewModel(message: response.message, isSuccess: true))
        case let .failure(error):
            let message = switch error {
            case .invalidEmailFormat:
                "El email no tiene un formato válido."
            case .emailNotFound:
                "No existe ninguna cuenta asociada a ese email."
            case .network:
                "Error de conexión. Inténtalo de nuevo."
            case .unknown:
                "Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo más tarde."
            }
            view?.display(PasswordRecoveryViewModel(message: message, isSuccess: false))
        }
    }
}
