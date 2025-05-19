import Foundation

public final class RemoteTokenRefreshService: TokenRefreshService {
    private let httpClient: HTTPClient
    private let tokenStorage: TokenStorage
    private let tokenParser: TokenParser
    private let refreshURL: URL

    public init(httpClient: HTTPClient, tokenStorage: TokenStorage, tokenParser: TokenParser, refreshURL: URL) {
        self.httpClient = httpClient
        self.tokenStorage = tokenStorage
        self.tokenParser = tokenParser
        self.refreshURL = refreshURL
    }

    public func refreshToken(refreshToken: String) async -> Result<TokenRefreshResult, TokenRefreshError> {
        var usedRefreshToken = refreshToken
        if usedRefreshToken.isEmpty, let loaded = try? await tokenStorage.loadRefreshToken() {
            usedRefreshToken = loaded
        }
        if usedRefreshToken.isEmpty {
            return .failure(.invalidRefreshToken)
        }

        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(["refreshToken": usedRefreshToken])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await httpClient.send(request)
            guard response.statusCode == 200 else {
                if response.statusCode == 401 {
                    return .failure(.invalidRefreshToken)
                }
                return .failure(.server(message: "status \(response.statusCode)"))
            }
            let newToken = try tokenParser.parse(from: data)
            try await tokenStorage.save(newToken)
            return .success(TokenRefreshResult(
                accessToken: newToken.value,
                refreshToken: refreshToken,
                expiry: newToken.expiry
            ))
        } catch {
            return .failure(.network)
        }
    }
}
