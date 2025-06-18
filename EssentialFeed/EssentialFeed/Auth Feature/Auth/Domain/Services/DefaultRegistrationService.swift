import Foundation

public final class DefaultRegistrationService: RegistrationService {
    private let registrationAPI: UserRegistrationAPI
    private let tokenStorage: TokenStorage
    private let offlineStore: OfflineRegistrationStore

    public init(registrationAPI: UserRegistrationAPI, tokenStorage: TokenStorage, offlineStore: OfflineRegistrationStore) {
        self.registrationAPI = registrationAPI
        self.tokenStorage = tokenStorage
        self.offlineStore = offlineStore
    }

    public func register(name: String, email: String, password: String) async -> UserRegistrationResult {
        let userData = UserRegistrationData(name: name, email: email, password: password)
        let result = await registrationAPI.register(with: userData)

        switch result {
        case let .success(response):
            let token = Token(accessToken: response.token, expiry: Date().addingTimeInterval(3600), refreshToken: response.refreshToken)
            let user = User(name: name, email: email)

            do {
                try await tokenStorage.save(tokenBundle: token)
                return .success(TokenAndUser(token: token, user: user))
            } catch {
                return .failure(error)
            }
        case let .failure(error):
            return .failure(error)
        }
    }
}
