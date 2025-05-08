import Foundation

public typealias RegistrationPersistenceInterfaces = KeychainProtocol & TokenStorage & OfflineRegistrationStore

public struct User: Equatable {
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
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .clientError(let statusCode):
            return "Client error with status code: \(statusCode)."
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)."
        case .noConnectivity:
            return "No internet connection."
        case .unknown:
            return "An unknown error occurred."
        }
    }
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
    private let persistence: RegistrationPersistenceInterfaces
    private let validator: RegistrationValidatorProtocol
    private let httpClient: HTTPClient
    private let registrationEndpoint: URL
    private let notifier: UserRegistrationNotifier?
    
    public init(
        persistence: RegistrationPersistenceInterfaces,
        validator: RegistrationValidatorProtocol,
        httpClient: HTTPClient,
        registrationEndpoint: URL,
        notifier: UserRegistrationNotifier? = nil
    ) {
        self.persistence = persistence
        self.validator = validator
        self.httpClient = httpClient
        self.registrationEndpoint = registrationEndpoint
        self.notifier = notifier
    }
    
    public func register(name: String, email: String, password: String) async -> UserRegistrationResult {
        if let validationError = validator.validate(name: name, email: email, password: password) {
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
            
            let (data, httpResponse) = try await httpClient.send(request)
            
            switch httpResponse.statusCode {
            case 201:
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let serverResponse = try decoder.decode(ServerAuthResponse.self, from: data)
                    let receivedToken = Token(value: serverResponse.token.value, expiry: serverResponse.token.expiry)
                    
                    try await persistence.save(receivedToken)
                    _ = persistence.save(data: password.data(using: .utf8)!, forKey: email)
                    
                    return .success(User(name: name, email: email))
                    
                } catch let tokenError as TokenParsingError {
                    notifier?.notifyRegistrationFailed(with: tokenError)
                    return .failure(tokenError)
                } catch {
                    notifier?.notifyRegistrationFailed(with: error)
                    return .failure(error)
                }
            case 409:
                notifier?.notifyRegistrationFailed(with: UserRegistrationError.emailAlreadyInUse)
                return .failure(UserRegistrationError.emailAlreadyInUse)
            case 400..<500:
                let clientError = NetworkError.clientError(statusCode: httpResponse.statusCode)
                notifier?.notifyRegistrationFailed(with: clientError)
                return .failure(clientError)
            case 500..<600:
                let serverError = NetworkError.serverError(statusCode: httpResponse.statusCode)
                notifier?.notifyRegistrationFailed(with: serverError)
                return .failure(serverError)
            default:
                notifier?.notifyRegistrationFailed(with: NetworkError.unknown)
                return .failure(NetworkError.unknown)
            }
        } catch let error as NetworkError {
            notifier?.notifyRegistrationFailed(with: error)
            return .failure(error)
        } catch {
            if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                do {
                    try await persistence.save(userData)
                } catch {
                    notifier?.notifyRegistrationFailed(with: error)
                }
                notifier?.notifyRegistrationFailed(with: NetworkError.noConnectivity)
                return .failure(NetworkError.noConnectivity)
            } else {
                notifier?.notifyRegistrationFailed(with: error)
                return .failure(error)
            }
        }
    }
}
