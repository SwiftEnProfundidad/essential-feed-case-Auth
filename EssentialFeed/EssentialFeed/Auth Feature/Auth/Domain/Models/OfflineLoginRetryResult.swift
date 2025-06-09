import Foundation

public struct OfflineLoginRetryResult {
    public let credentials: LoginCredentials
    public let loginResult: Result<LoginResponse, LoginError>

    public init(credentials: LoginCredentials, loginResult: Result<LoginResponse, LoginError>) {
        self.credentials = credentials
        self.loginResult = loginResult
    }

    public var isSuccessful: Bool {
        if case .success = loginResult { return true }
        return false
    }
}
