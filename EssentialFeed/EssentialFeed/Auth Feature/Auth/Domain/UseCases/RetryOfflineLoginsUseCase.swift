import Foundation

public final class RetryOfflineLoginsUseCase {
    private let offlineStore: OfflineLoginLoading
    private let loginAPI: UserLoginAPI

    public init(offlineStore: OfflineLoginLoading, loginAPI: UserLoginAPI) {
        self.offlineStore = offlineStore
        self.loginAPI = loginAPI
    }

    public func execute() async throws -> [OfflineLoginRetryResult] {
        let requests = try await offlineStore.loadAll()
        var results: [OfflineLoginRetryResult] = []

        for credentials in requests {
            let loginResult = await loginAPI.login(with: credentials)
            let result = OfflineLoginRetryResult(
                credentials: credentials,
                loginResult: loginResult
            )
            results.append(result)
        }

        return results
    }
}
