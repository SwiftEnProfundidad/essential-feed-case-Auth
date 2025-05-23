import EssentialFeed

final class AuthUseCaseSpy: AuthUseCaseProtocol {
    private(set) var messages = [(username: String, password: String)]()
    private(set) var refreshTokenCalls = [String]()

    var executeResult: Result<LoginResponse, LoginError> = .failure(.invalidCredentials)
    var refreshTokenResult: Result<TokenRefreshResult, TokenRefreshError> = .failure(.invalidRefreshToken)

    func execute(username: String, password: String) async -> Result<LoginResponse, LoginError> {
        messages.append((username, password))
        return executeResult
    }

    func refreshToken(refreshToken: String) async -> Result<TokenRefreshResult, TokenRefreshError> {
        refreshTokenCalls.append(refreshToken)
        return refreshTokenResult
    }
}
