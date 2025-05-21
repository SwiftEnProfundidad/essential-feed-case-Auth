import Foundation

public final class RetryOfflineRegistrationsUseCase {
    private let offlineStore: OfflineRegistrationStoreCRUD
    private let userLoginAPI: UserLoginAPI
    private let tokenStorage: TokenStorage
    private let userRegistrationAPI: UserRegistrationAPI

    public enum Error: Swift.Error {
        case registrationFailed(UserRegistrationError)
        case tokenStorageFailed(Swift.Error)
        case offlineStoreLoadFailed(Swift.Error)
        case offlineStoreDeleteFailed(Swift.Error)
        case internalError
    }

    public init(offlineStore: OfflineRegistrationStoreCRUD, authAPI: UserLoginAPI, tokenStorage: TokenStorage, userRegistration: UserRegistrationAPI) {
        self.offlineStore = offlineStore
        self.userLoginAPI = authAPI
        self.tokenStorage = tokenStorage
        self.userRegistrationAPI = userRegistration
    }

    public func execute() async -> [Result<Void, RetryOfflineRegistrationsUseCase.Error>] {
        let registrationsToRetry: [UserRegistrationData]
        do {
            registrationsToRetry = try await offlineStore.loadAll()
        } catch {
            return [.failure(.offlineStoreLoadFailed(error))]
        }

        if registrationsToRetry.isEmpty {
            return []
        }

        var results = [Result<Void, RetryOfflineRegistrationsUseCase.Error>]()

        for data in registrationsToRetry {
            let apiResult = await userRegistrationAPI.register(with: data)

            switch apiResult {
            case let .success(response):
                do {
                    let expiryDate = Date().addingTimeInterval(3600)
                    let tokenToStore = Token(
                        accessToken: response.token,
                        expiry: expiryDate,
                        refreshToken: response.refreshToken
                    )
                    try await tokenStorage.save(tokenBundle: tokenToStore)
                } catch {
                    results.append(.failure(.tokenStorageFailed(error)))
                    continue
                }
                do {
                    try await offlineStore.delete(data)
                    results.append(.success(()))
                } catch {
                    results.append(.failure(.offlineStoreDeleteFailed(error)))
                }
            case let .failure(registrationError):
                results.append(.failure(.registrationFailed(registrationError)))
            }
        }
        return results
    }
}
