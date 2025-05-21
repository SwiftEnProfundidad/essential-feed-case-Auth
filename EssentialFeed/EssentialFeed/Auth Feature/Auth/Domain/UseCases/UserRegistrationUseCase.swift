import Foundation

public protocol UserRegisterer: AnyObject {
    func register(name: String, email: String, password: String) async -> UserRegistrationResult
}

public protocol UserRegistrationPersistenceService {
    func save(tokenBundle: Token) async throws
    func saveCredentials(passwordData: Data, forEmail email: String) -> KeychainSaveResult
    func saveForOfflineProcessing(registrationData: UserRegistrationData) async throws
}

public enum RegistrationValidationError: Error, Equatable {
    case emptyName
    case invalidEmail
    case weakPassword
}

public protocol RegistrationValidatorProtocol: AnyObject {
    func validate(name: String, email: String, password: String) -> RegistrationValidationError?
}

public enum UserRegistrationResult {
    case success(User)
    case failure(Error)
}

public protocol UserRegistrationNotifier {
    func notifyRegistrationFailed(with error: Error)
}

public actor UserRegistrationUseCase: UserRegisterer {
    private let persistenceService: UserRegistrationPersistenceService
    private let validator: RegistrationValidatorProtocol
    private let httpClient: HTTPClient
    private let registrationEndpoint: URL
    private let notifier: UserRegistrationNotifier?

    public init(
        persistenceService: UserRegistrationPersistenceService,
        validator: RegistrationValidatorProtocol,
        httpClient: HTTPClient,
        registrationEndpoint: URL,
        notifier: UserRegistrationNotifier? = nil
    ) {
        self.persistenceService = persistenceService
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
            let request = try makeRequest(for: userData)
            let (data, httpResponse) = try await httpClient.send(request)
            return await mapHTTPResponseToRegistrationResult(data: data, httpResponse: httpResponse, for: userData)
        } catch {
            return await handleRegistrationError(error, for: userData)
        }
    }

    private func makeRequest(for userData: UserRegistrationData) throws -> URLRequest {
        var request = URLRequest(url: registrationEndpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "name": userData.name,
            "email": userData.email,
            "password": userData.password
        ])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func mapHTTPResponseToRegistrationResult(data: Data, httpResponse: HTTPURLResponse, for userData: UserRegistrationData) async -> UserRegistrationResult {
        switch httpResponse.statusCode {
        case 201:
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let serverResponse = try decoder.decode(ServerAuthResponse.self, from: data)
                let receivedToken = Token(
                    accessToken: serverResponse.token.value,
                    expiry: serverResponse.token.expiry,
                    refreshToken: nil
                )

                try await persistenceService.save(tokenBundle: receivedToken)
                _ = persistenceService.saveCredentials(
                    passwordData: userData.password.data(using: .utf8)!,
                    forEmail: userData.email
                )

                return .success(User(name: userData.name, email: userData.email))
            } catch let tokenError as TokenParsingError {
                notifier?.notifyRegistrationFailed(with: tokenError)
                return .failure(tokenError)
            } catch let decodingError as DecodingError {
                notifier?.notifyRegistrationFailed(with: decodingError)
                return .failure(decodingError)
            } catch {
                notifier?.notifyRegistrationFailed(with: error)
                return .failure(error)
            }
        case 409:
            notifier?.notifyRegistrationFailed(with: UserRegistrationError.emailAlreadyInUse)
            return .failure(UserRegistrationError.emailAlreadyInUse)
        case 400 ..< 500:
            let clientError = NetworkError.clientError(statusCode: httpResponse.statusCode)
            notifier?.notifyRegistrationFailed(with: clientError)
            return .failure(clientError)
        case 500 ..< 600:
            let serverError = NetworkError.serverError(statusCode: httpResponse.statusCode)
            notifier?.notifyRegistrationFailed(with: serverError)
            return .failure(serverError)
        default:
            notifier?.notifyRegistrationFailed(with: NetworkError.unknown)
            return .failure(NetworkError.unknown)
        }
    }

    private func handleRegistrationError(_ error: Error, for userData: UserRegistrationData) async -> UserRegistrationResult {
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            do {
                try await persistenceService.saveForOfflineProcessing(registrationData: userData)
            } catch let offlineStoreError {
                notifier?.notifyRegistrationFailed(with: offlineStoreError)
                // Note: The original logic only notified. If this offline save failure
                // should also make the overall registration fail with this specific error,
                // we might consider returning .failure(offlineStoreError) here.
                // For now, sticking to notifying and then proceeding to notify/return .noConnectivity.
            }
            notifier?.notifyRegistrationFailed(with: NetworkError.noConnectivity)
            return .failure(NetworkError.noConnectivity)
        } else {
            notifier?.notifyRegistrationFailed(with: error)
            return .failure(error)
        }
    }
}
