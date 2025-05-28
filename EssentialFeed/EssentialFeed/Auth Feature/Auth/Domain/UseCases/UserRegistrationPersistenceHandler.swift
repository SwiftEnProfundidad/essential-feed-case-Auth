import Foundation

public protocol UserRegistrationPersistenceHandling {
    func saveUserData(token: Token, userData: UserRegistrationData) async throws -> User
    func saveForOfflineProcessing(userData: UserRegistrationData) async throws
}

public actor UserRegistrationPersistenceHandler: UserRegistrationPersistenceHandling {
    private let persistenceService: UserRegistrationPersistenceService
    private let notifier: UserRegistrationNotifier?

    public init(persistenceService: UserRegistrationPersistenceService, notifier: UserRegistrationNotifier? = nil) {
        self.persistenceService = persistenceService
        self.notifier = notifier
    }

    public func saveUserData(token: Token, userData: UserRegistrationData) async throws -> User {
        try await persistenceService.save(tokenBundle: token)

        let saveResult = persistenceService.saveCredentials(passwordData: userData.password.data(using: .utf8)!, forEmail: userData.email)

        if saveResult != .success {
            throw UserRegistrationError.tokenStorageFailed
        }

        return User(name: userData.name, email: userData.email)
    }

    public func saveForOfflineProcessing(userData: UserRegistrationData) async throws {
        try await persistenceService.saveForOfflineProcessing(registrationData: userData)
    }
}
