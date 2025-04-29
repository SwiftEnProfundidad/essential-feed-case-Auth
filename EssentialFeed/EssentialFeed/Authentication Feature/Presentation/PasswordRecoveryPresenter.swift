import Foundation

public final class PasswordRecoveryPresenter {
	private weak var view: (PasswordRecoveryView)?
	
	public init(view: PasswordRecoveryView) {
		self.view = view
	}
	
	public func didRecoverPassword(with result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
		switch result {
			case let .success(response):
				view?.display(PasswordRecoveryViewModel(message: response.message, isSuccess: true))
			case let .failure(error):
				let message: String
				switch error {
					case .invalidEmailFormat:
						message = "Introduce un email válido."
					case .emailNotFound:
						message = "No existe ninguna cuenta asociada a ese email."
					case .network:
						message = "No se ha podido conectar con el servidor. Comprueba tu conexión e inténtalo de nuevo."
					case .unknown:
						message = "Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo más tarde."
				}
				view?.display(PasswordRecoveryViewModel(message: message, isSuccess: false))
		}
	}
}


