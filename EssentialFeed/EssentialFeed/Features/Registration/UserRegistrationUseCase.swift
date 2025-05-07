import Foundation

public struct User {
	public let name: String
	public let email: String
	
	public init(name: String, email: String) {
		self.name = name
		self.email = email
	}
}

public struct UserRegistrationData: Codable, Equatable {
	public let name: String
	public let email: String
	public let password: String
	
	public init(name: String, email: String, password: String) {
		self.name = name
		self.email = email
		self.password = password
	}
}

public enum RegistrationValidationError: Error, Equatable {
	case emptyName
	case invalidEmail
	case weakPassword
}

public protocol RegistrationValidatorProtocol {
	func validate(name: String, email: String, password: String) -> RegistrationValidationError?
}

public enum UserRegistrationError: Error, Equatable {
	case emailAlreadyInUse
}

public enum UserRegistrationResult {
	case success(User)
	case failure(Error)
}

public enum NetworkError: Error, Equatable {
	case invalidResponse
	case clientError(statusCode: Int)
	case serverError(statusCode: Int)
	case unknown
	case noConnectivity
}

public protocol UserRegistrationNotifier {
	func notifyRegistrationFailed(with error: Error)
}

public enum TokenParsingError: Error, Equatable {
	case invalidData
	case missingToken
}

private struct ServerAuthResponse: Codable {
	struct UserPayload: Codable {
		let name: String
		let email: String
	}
	struct TokenPayload: Codable {
		let value: String
		let expiry: Date
	}
	let user: UserPayload
	let token: TokenPayload
}

public actor UserRegistrationUseCase {
	private let keychain: KeychainProtocol
	private let tokenStorage: TokenStorage
	private let offlineStore: OfflineRegistrationStore
	private let validator: RegistrationValidatorProtocol
	private let httpClient: HTTPClient
	private let registrationEndpoint: URL
	private let notifier: UserRegistrationNotifier?
	
	/**Constructor con demasiadas dependencias (Violación del Principio de Responsabilidad Única - SRP)**: El `init`  ha crecido y está manejando varias dependencias distintas:
	 *   `keychain: KeychainProtocol`
	 *   `tokenStorage: TokenStorage`
	 *   `offlineStore: OfflineRegistrationStore` (la nueva)
	 *   `validator: RegistrationValidatorProtocol`
	 *   `httpClient: HTTPClient`
	 *   `registrationEndpoint: URL`
	 *   `notifier: UserRegistrationNotifier?`
	 
	 Esto indica que podría estar asumiendo demasiadas responsabilidades.
	 A largo plazo, sería beneficioso refactorizar esto. Podríamos considerar:
	 *
	 *   Agrupar algunas dependencias relacionadas bajo una nueva abstracción (por ejemplo, un `AuthPersistenceService` que maneje `keychain`, `tokenStorage` y `offlineStore`).
	 *   Utilizar un Patrón Fachada (Facade) para simplificar la interfaz con múltiples subsistemas.
	 *   Evaluar si alguna de estas responsabilidades podría ser manejada por un componente coordinador o compositor en una capa superior.
	 **/
	public init(keychain: KeychainProtocol, tokenStorage: TokenStorage, offlineStore: OfflineRegistrationStore, validator: RegistrationValidatorProtocol, httpClient: HTTPClient, registrationEndpoint: URL, notifier: UserRegistrationNotifier? = nil) {
		self.keychain = keychain
		self.tokenStorage = tokenStorage
		self.offlineStore = offlineStore
		self.validator = validator
		self.httpClient = httpClient
		self.registrationEndpoint = registrationEndpoint
		self.notifier = notifier
	}
	
	public func register(name: String, email: String, password: String) async -> UserRegistrationResult {
		if let validationError = validator.validate(name: name, email: email, password: password) {
			print("UserRegistrationUseCase: Validation failed: \(validationError)")
			notifier?.notifyRegistrationFailed(with: validationError)
			return .failure(validationError)
		}
		
		let userData = UserRegistrationData(name: name, email: email, password: password)
		
		do {
			var request = URLRequest(url: registrationEndpoint)
			request.httpMethod = "POST"
			request.httpBody = try JSONSerialization.data(withJSONObject: [
				"name": userData.name,
				"email": userData.email,
				"password": userData.password
			])
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
			
			print("UserRegistrationUseCase: Sending HTTP request...")
			let (data, httpResponse) = try await httpClient.send(request)
			print("UserRegistrationUseCase: Received HTTP response: \(httpResponse.statusCode)")
			
			switch httpResponse.statusCode {
				case 201:
					do {
						print("UserRegistrationUseCase: Handling 201 Created...")
						let decoder = JSONDecoder()
						decoder.dateDecodingStrategy = .iso8601
						let serverResponse = try decoder.decode(ServerAuthResponse.self, from: data)
						let receivedToken = Token(value: serverResponse.token.value, expiry: serverResponse.token.expiry)
						
						print("UserRegistrationUseCase: Saving token...")
						try await tokenStorage.save(receivedToken)
						
						print("UserRegistrationUseCase: Saving credentials...")
						saveCredentials(email: email, password: password)
						print("UserRegistrationUseCase: Registration success.")
						return .success(User(name: name, email: email))
						
					} catch let tokenError as TokenParsingError {
						print("UserRegistrationUseCase: Token parsing error: \(tokenError)")
						notifier?.notifyRegistrationFailed(with: tokenError)
						return .failure(tokenError)
					} catch {
						print("UserRegistrationUseCase: Error during success handling: \(error)")
						notifier?.notifyRegistrationFailed(with: error)
						return .failure(error)
					}
				case 409:
					print("UserRegistrationUseCase: Handling 409 Conflict (Email in use)...")
					notifier?.notifyRegistrationFailed(with: UserRegistrationError.emailAlreadyInUse)
					return .failure(UserRegistrationError.emailAlreadyInUse)
				case 400..<500:
					print("UserRegistrationUseCase: Handling client error \(httpResponse.statusCode)...")
					let clientError = NetworkError.clientError(statusCode: httpResponse.statusCode)
					notifier?.notifyRegistrationFailed(with: clientError)
					return .failure(clientError)
				case 500..<600:
					print("UserRegistrationUseCase: Handling server error \(httpResponse.statusCode)...")
					let serverError = NetworkError.serverError(statusCode: httpResponse.statusCode)
					notifier?.notifyRegistrationFailed(with: serverError)
					return .failure(serverError)
				default:
					print("UserRegistrationUseCase: Handling unknown status code \(httpResponse.statusCode)...")
					notifier?.notifyRegistrationFailed(with: NetworkError.unknown)
					return .failure(NetworkError.unknown)
			}
		} catch let error as NetworkError {
			print("UserRegistrationUseCase: Caught NetworkError: \(error)")
			return .failure(error)
		} catch {
			print("UserRegistrationUseCase: Caught other error: \(error)")
			if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
				print("UserRegistrationUseCase: Detected no connectivity error. Saving data offline...")
				do {
					try await offlineStore.save(userData)
					print("UserRegistrationUseCase: Data saved offline.")
				} catch {
					print("UserRegistrationUseCase: FAILED to save data offline: \(error)")
					notifier?.notifyRegistrationFailed(with: error)
				}
				notifier?.notifyRegistrationFailed(with: NetworkError.noConnectivity)
				return .failure(NetworkError.noConnectivity)
			} else {
				print("UserRegistrationUseCase: Propagating other error.")
				notifier?.notifyRegistrationFailed(with: error)
				return .failure(error)
			}
		}
	}
	
	private func saveCredentials(email: String, password: String) {
		_ = keychain.save(data: password.data(using: .utf8)!, forKey: email)
	}
}
