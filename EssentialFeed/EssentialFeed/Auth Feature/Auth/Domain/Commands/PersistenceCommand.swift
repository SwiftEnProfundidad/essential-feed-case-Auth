import Foundation

public final class PersistenceCommand: RegistrationCommand {
    private let persistenceService: RegistrationPersistenceService

    public init(persistenceService: RegistrationPersistenceService) {
        self.persistenceService = persistenceService
    }

    public func execute(_ context: RegistrationContext) async throws -> RegistrationContext {
        guard let tokenAndUser = context.tokenAndUser else {
            throw RegistrationError.missingTokenAndUser
        }

        var newContext = context
        newContext.savedUser = try await persistenceService.persistUserRegistration(
            token: tokenAndUser.token,
            userData: context.userData
        )
        return newContext
    }
}
