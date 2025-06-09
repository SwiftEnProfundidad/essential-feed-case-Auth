import Foundation

// MARK: - ISP-Compliant Registration Persistence Service

public protocol RegistrationPersistenceService {
    func persistUserRegistration(token: Token, userData: UserRegistrationData) async throws -> User
}

// MARK: - Dependency Composition (using existing ISP-compliant protocols)

public final class DefaultRegistrationPersistenceService: RegistrationPersistenceService {
    private let tokenStorage: TokenWriter
    private let credentialsStore: KeychainSavable
    private let offlineStore: OfflineRegistrationStore

    public init(
        tokenStorage: TokenWriter,
        credentialsStore: KeychainSavable,
        offlineStore: OfflineRegistrationStore
    ) {
        self.tokenStorage = tokenStorage
        self.credentialsStore = credentialsStore
        self.offlineStore = offlineStore
    }

    public func persistUserRegistration(token: Token, userData: UserRegistrationData) async throws -> User {
        try await tokenStorage.save(tokenBundle: token)

        let passwordData = userData.password.data(using: .utf8) ?? Data()
        let credentialsSaveResult = credentialsStore.save(data: passwordData, forKey: userData.email)

        guard credentialsSaveResult == .success else {
            throw UserRegistrationError.credentialsSaveFailed
        }

        return User(name: userData.name, email: userData.email)
    }
}

// MARK: - Offline Handler Service (separate responsibility)

public protocol OfflineRegistrationHandler {
    func handleOfflineRegistration(_ userData: UserRegistrationData) async throws
}

public final class DefaultOfflineRegistrationHandler: OfflineRegistrationHandler {
    private let offlineStore: OfflineRegistrationStore
    private let notifier: UserRegistrationNotifier?

    public init(
        offlineStore: OfflineRegistrationStore,
        notifier: UserRegistrationNotifier? = nil
    ) {
        self.offlineStore = offlineStore
        self.notifier = notifier
    }

    public func handleOfflineRegistration(_ userData: UserRegistrationData) async throws {
        do {
            try await offlineStore.save(userData)
        } catch {
            notifier?.notifyRegistrationFailed(with: error)
            throw error
        }
    }
}
