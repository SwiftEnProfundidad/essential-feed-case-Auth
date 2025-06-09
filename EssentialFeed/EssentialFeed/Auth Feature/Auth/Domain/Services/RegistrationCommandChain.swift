import Foundation

public final class RegistrationCommandChain: RegistrationService {
    private let commands: [RegistrationCommand]
    private let offlineHandler: OfflineRegistrationHandler
    private let notifier: UserRegistrationNotifier?

    public init(
        commands: [RegistrationCommand],
        offlineHandler: OfflineRegistrationHandler,
        notifier: UserRegistrationNotifier? = nil
    ) {
        self.commands = commands
        self.offlineHandler = offlineHandler
        self.notifier = notifier
    }

    public func register(name: String, email: String, password: String) async -> UserRegistrationResult {
        let userData = UserRegistrationData(name: name, email: email, password: password)
        var context = RegistrationContext(userData: userData)

        do {
            for command in commands {
                context = try await command.execute(context)
            }

            guard let tokenAndUser = context.tokenAndUser,
                  let savedUser = context.savedUser
            else {
                throw RegistrationError.incompleteExecution
            }

            return .success(TokenAndUser(token: tokenAndUser.token, user: savedUser))

        } catch {
            return await handleRegistrationError(error, for: userData)
        }
    }

    private func handleRegistrationError(_ error: Error, for userData: UserRegistrationData) async -> UserRegistrationResult {
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            do {
                try await offlineHandler.handleOfflineRegistration(userData)
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
