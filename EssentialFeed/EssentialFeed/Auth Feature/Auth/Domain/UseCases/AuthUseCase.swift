// MARK: - AuthUseCaseProtocol

public protocol AuthUseCaseProtocol {
    func execute(username: String, password: String) async -> Result<LoginResponse, LoginError>
    func refreshToken(refreshToken: String) async -> Result<TokenRefreshResult, TokenRefreshError>
}

// MARK: - AuthUseCase

public final class AuthUseCase: AuthUseCaseProtocol {
    private let authenticate: (String, String) async -> Result<LoginResponse, LoginError>
    private let tokenRefreshService: TokenRefreshService
    private let pendingRequestStore: AnyLoginRequestStore?

    public init(
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>,
        tokenRefreshService: TokenRefreshService,
        pendingRequestStore: AnyLoginRequestStore? = nil
    ) {
        self.authenticate = authenticate
        self.tokenRefreshService = tokenRefreshService
        self.pendingRequestStore = pendingRequestStore
    }

    public func execute(username: String, password: String) async -> Result<LoginResponse, LoginError> {
        let result = await authenticate(username, password)

        if case let .failure(error) = result, error.isNetworkError {
            let request = LoginRequest(username: username, password: password)
            pendingRequestStore?.save(request)
        }

        return result
    }

    public func refreshToken(refreshToken: String) async -> Result<TokenRefreshResult, TokenRefreshError> {
        await tokenRefreshService.refreshToken(refreshToken: refreshToken)
    }
}

// MARK: - Helpers

private extension LoginError {
    var isNetworkError: Bool {
        if case .network = self { return true }
        return false
    }
}
