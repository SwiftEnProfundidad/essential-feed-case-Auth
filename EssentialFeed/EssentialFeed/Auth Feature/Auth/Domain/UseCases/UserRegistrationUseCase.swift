import Foundation

public protocol UserRegisterer: AnyObject {
    func register(name: String, email: String, password: String) async -> UserRegistrationResult
}

public protocol UserRegistrationPersistenceService {
    func save(tokenBundle: Token) async throws
    func saveCredentials(passwordData: Data, forEmail email: String) -> KeychainSaveResult
    func saveForOfflineProcessing(registrationData: UserRegistrationData) async throws
    func load(forKey key: String) -> Data?
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
    case success(TokenAndUser)
    case failure(Error)
}

public protocol UserRegistrationNotifier {
    func notifyRegistrationFailed(with error: Error)
}

public actor UserRegistrationUseCase: UserRegisterer {
    private let persistenceHandler: UserRegistrationPersistenceHandling
    private let responseMapper: UserRegistrationResponseMapping
    private let validator: RegistrationValidatorProtocol
    private let httpClient: HTTPClient
    private let registrationEndpoint: URL
    private let notifier: UserRegistrationNotifier?

    public init(
        persistenceService: UserRegistrationPersistenceService,
        validator: RegistrationValidatorProtocol,
        httpClient: HTTPClient,
        registrationEndpoint: URL,
        notifier: UserRegistrationNotifier? = nil,
        responseMapper: UserRegistrationResponseMapping? = nil,
        persistenceHandler: UserRegistrationPersistenceHandling? = nil
    ) {
        self.persistenceHandler = persistenceHandler ?? UserRegistrationPersistenceHandler(persistenceService: persistenceService, notifier: notifier)
        self.responseMapper = responseMapper ?? UserRegistrationResponseMapper(notifier: notifier)
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

            let result = await responseMapper.map(data: data, httpResponse: httpResponse, for: userData)

            switch result {
            case let .success(tokenAndUser):
                do {
                    let savedUser = try await persistenceHandler.saveUserData(token: tokenAndUser.token, userData: userData)
                    return .success(TokenAndUser(token: tokenAndUser.token, user: savedUser))
                } catch {
                    notifier?.notifyRegistrationFailed(with: error)
                    return .failure(error)
                }
            case let .failure(error):
                notifier?.notifyRegistrationFailed(with: error)
                return .failure(error)
            }
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

    private func handleRegistrationError(_ error: Error, for userData: UserRegistrationData) async -> UserRegistrationResult {
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            do {
                try await persistenceHandler.saveForOfflineProcessing(userData: userData)
            } catch let offlineStoreError {
                notifier?.notifyRegistrationFailed(with: offlineStoreError)
            }
            notifier?.notifyRegistrationFailed(with: NetworkError.noConnectivity)
            return .failure(NetworkError.noConnectivity)
        } else {
            notifier?.notifyRegistrationFailed(with: error)
            return .failure(error)
        }
    }
}
