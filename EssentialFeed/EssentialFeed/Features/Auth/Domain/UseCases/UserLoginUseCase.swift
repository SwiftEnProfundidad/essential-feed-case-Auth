import Foundation

public struct LoginCredentials {
	public let email: String
	public let password: String
	public init(email: String, password: String) {
		self.email = email
		self.password = password
	}
}

public struct LoginResponse: Equatable {
	public let token: String
	public init(token: String) {
		self.token = token
	}
}

public protocol AuthAPI {
	func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError>
}

public enum LoginError: Error, Equatable {
	case invalidCredentials
	case network
	case invalidEmailFormat
	case invalidPasswordFormat
	case tokenStorageFailed
	case unknown
}

public protocol LoginSuccessObserver {
	func didLoginSuccessfully(response: LoginResponse)
}

public protocol LoginFailureObserver {
	func didFailLogin(error: LoginError)
}

public final class UserLoginUseCase {
	private let api: AuthAPI
	private let tokenStorage: TokenStorage
	private let successObserver: LoginSuccessObserver?
	private let failureObserver: LoginFailureObserver?
	
	public init(api: AuthAPI, tokenStorage: TokenStorage, successObserver: LoginSuccessObserver? = nil, failureObserver: LoginFailureObserver? = nil) {
		self.api = api
		self.tokenStorage = tokenStorage
		self.successObserver = successObserver
		self.failureObserver = failureObserver
	}
	
	public func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
		// VALIDACIÓN DE EMAIL
		let email = credentials.email.trimmingCharacters(in: .whitespacesAndNewlines)
		if email.isEmpty {
			failureObserver?.didFailLogin(error: .invalidEmailFormat)
			return .failure(.invalidEmailFormat)
		}
		// Validación de formato de email simple (deberías usar una más robusta si es necesario)
		// Por ejemplo, una expresión regular o un validador dedicado.
		// Para que los tests pasen con "usuario_invalido", verificamos la ausencia de "@" o una estructura básica.
		// Una validación muy básica que podría servir para el test "usuario_invalido"
		// y aun así permitir emails válidos.
		if !isValidEmail(email) {
			failureObserver?.didFailLogin(error: .invalidEmailFormat)
			return .failure(.invalidEmailFormat)
		}
		
		// VALIDACIÓN DE CONTRASEÑA
		let password = credentials.password // Generalmente no se hace trim a las contraseñas antes de validarlas en el backend,
																				// pero para la validación de formato local "solo espacios" sí.
		
		if password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty { // Si es solo espacios pero no vacía
			failureObserver?.didFailLogin(error: .invalidPasswordFormat)
			return .failure(.invalidPasswordFormat)
		}
		
		if password.isEmpty { // Si es completamente vacía
			failureObserver?.didFailLogin(error: .invalidPasswordFormat)
			return .failure(.invalidPasswordFormat)
		}
		
		// Asumiendo una longitud mínima de 6 caracteres para que pase el test "12345"
		if password.count < 6 {
			failureObserver?.didFailLogin(error: .invalidPasswordFormat)
			return .failure(.invalidPasswordFormat)
		}
		
		// Si todas las validaciones pasan, entonces sí llamamos a la API:
		let result = await api.login(with: credentials)
		
		switch result {
			case .success(let response):
				print("[LoginUseCase] API Success. Response token: \(response.token)")
				let defaultTokenDuration: TimeInterval = 3600
				let expiryDate = Date().addingTimeInterval(defaultTokenDuration)
				
				print("[LoginUseCase] Attempting to create Token object...")
				let tokenToStore = Token(value: response.token, expiry: expiryDate)
				print("[LoginUseCase] Token object created: \(tokenToStore.value)")
				
				do {
					print("[LoginUseCase] Attempting: try await tokenStorage.save(token)...")
					try await tokenStorage.save(tokenToStore)
					print("[LoginUseCase] tokenStorage.save() SUCCEEDED.")
					print("[LoginUseCase] Notifying successObserver and returning .success")
					successObserver?.didLoginSuccessfully(response: response)
					return .success(response)
				} catch {
					print("[LoginUseCase] tokenStorage.save() FAILED with error: \(error)")
					print("[LoginUseCase] Notifying failureObserver and returning .failure(.tokenStorageFailed)")
					failureObserver?.didFailLogin(error: .tokenStorageFailed)
					return .failure(.tokenStorageFailed)
				}
				
			case .failure(let error):
				print("[LoginUseCase] API Failure. Error: \(error)")
				failureObserver?.didFailLogin(error: error)
				return .failure(error)
		}
	}
	
	private func isValidEmail(_ email: String) -> Bool {
		// Una expresión regular muy básica para emails.
		// Deberías usar una más completa y probada para producción.
		let emailRegEx = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
		let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
		return emailPred.evaluate(with: email)
	}
}
