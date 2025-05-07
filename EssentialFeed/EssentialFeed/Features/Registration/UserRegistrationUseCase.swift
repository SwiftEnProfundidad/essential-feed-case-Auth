import Foundation

public struct User {
	public let name: String
	public let email: String
	
	public init(name: String, email: String) {
		self.name = name
		self.email = email
	}
}

public struct UserRegistrationData: Codable {
	let name: String
	let email: String
	let password: String
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
	func notifyEmailAlreadyInUse()
}

public actor UserRegistrationUseCase {
	private let keychain: KeychainProtocol
	private let validator: RegistrationValidatorProtocol
	private let httpClient: HTTPClient
	private let registrationEndpoint: URL
	private let notifier: UserRegistrationNotifier?
	
	public init(keychain: KeychainProtocol, validator: RegistrationValidatorProtocol, httpClient: HTTPClient, registrationEndpoint: URL, notifier: UserRegistrationNotifier? = nil) {
		self.keychain = keychain
		self.validator = validator
		self.httpClient = httpClient
		self.registrationEndpoint = registrationEndpoint
		self.notifier = notifier
	}
	
	public func register(name: String, email: String, password: String) async -> UserRegistrationResult {
		if let validationError = validator.validate(name: name, email: email, password: password) {
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
			
			let (_, httpResponse) = try await httpClient.send(request)
			
			switch httpResponse.statusCode {
				case 201:
					saveCredentials(email: email, password: password)
					return .success(User(name: name, email: email))
				case 409:
					notifier?.notifyEmailAlreadyInUse()
					return .failure(UserRegistrationError.emailAlreadyInUse)
				case 400..<500:
					return .failure(NetworkError.clientError(statusCode: httpResponse.statusCode))
				case 500..<600:
					return .failure(NetworkError.serverError(statusCode: httpResponse.statusCode))
				default:
					return .failure(NetworkError.unknown)
			}
		} catch {
			return .failure(error)
		}
	}
	
	// MARK: - Private Helpers (Actor Context)
	private func saveCredentials(email: String, password: String) {
		_ = keychain.save(data: password.data(using: .utf8)!, forKey: email)
	}
}
