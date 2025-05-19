import Foundation

public final class RetryOfflineLoginsUseCase {
    private let offlineStore: OfflineLoginStore
    private let loginAPI: UserLoginAPI

    public init(offlineStore: OfflineLoginStore, loginAPI: UserLoginAPI) {
        self.offlineStore = offlineStore
        self.loginAPI = loginAPI
    }

    public func execute() async -> [Result<LoginResponse, LoginError>] {
        let requests = await offlineStore.loadAll()
        var results: [Result<LoginResponse, LoginError>] = []
        for req in requests {
            let result = await loginAPI.login(with: req)
            results.append(result)
            if case .success = result {
                try? await offlineStore.delete(credentials: req)
            }
        }
        return results
    }
}
