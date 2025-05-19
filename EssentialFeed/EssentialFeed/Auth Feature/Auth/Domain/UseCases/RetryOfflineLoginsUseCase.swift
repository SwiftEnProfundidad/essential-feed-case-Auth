import Foundation

public final class RetryOfflineLoginsUseCase {
    private let offlineStore: OfflineLoginStore
    private let loginAPI: UserLoginAPI

    public init(offlineStore: OfflineLoginStore, loginAPI: UserLoginAPI) {
        self.offlineStore = offlineStore
        self.loginAPI = loginAPI
    }

    public func execute() async -> [Any] {
        []
    }
}
