import Foundation

public protocol UserRegistrationPersistenceHandling {
    func saveUserData(token: Token, userData: UserRegistrationData) async throws -> User
    func saveForOfflineProcessing(userData: UserRegistrationData) async throws
}

public actor UserRegistrationPersistenceHandler: UserRegistrationPersistenceHandling {
    private let persistenceService: RegistrationPersistenceService
    private let offlineHandler: OfflineRegistrationHandler
    private let notifier: UserRegistrationNotifier?

    public init(
        persistenceService: RegistrationPersistenceService,
        offlineHandler: OfflineRegistrationHandler,
        notifier: UserRegistrationNotifier? = nil
    ) {
        self.persistenceService = persistenceService
        self.offlineHandler = offlineHandler
        self.notifier = notifier
    }

    public func saveUserData(token: Token, userData: UserRegistrationData) async throws -> User {
        do {
            return try await persistenceService.persistUserRegistration(token: token, userData: userData)
        } catch {
            notifier?.notifyRegistrationFailed(with: error)
            throw error
        }
    }

    public func saveForOfflineProcessing(userData: UserRegistrationData) async throws {
        do {
            try await offlineHandler.handleOfflineRegistration(userData)
        } catch {
            notifier?.notifyRegistrationFailed(with: error)
            throw error
        }
    }
}
