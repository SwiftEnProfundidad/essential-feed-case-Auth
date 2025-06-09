import Foundation

public protocol UserRegisterer: AnyObject {
    func register(name: String, email: String, password: String) async -> UserRegistrationResult
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

// MARK: - Registration Service Protocol

public protocol RegistrationService {
    func register(name: String, email: String, password: String) async -> UserRegistrationResult
}

// MARK: - Purified Use Case (SRP + DIP compliant)

public actor UserRegistrationUseCase: UserRegisterer {
    private let registrationService: RegistrationService

    public init(registrationService: RegistrationService) {
        self.registrationService = registrationService
    }

    public func register(name: String, email: String, password: String) async -> UserRegistrationResult {
        await registrationService.register(name: name, email: email, password: password)
    }
}
