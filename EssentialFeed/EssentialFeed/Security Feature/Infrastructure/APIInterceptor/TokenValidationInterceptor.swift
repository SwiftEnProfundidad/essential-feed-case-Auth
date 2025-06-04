import Foundation

public protocol AuthenticationLogger {
    func logTokenLoadFailure(_ error: Error)
}

public final class TokenValidationInterceptor: HTTPClientInterceptor {
    private let tokenStorage: TokenReader
    private let validationStrategy: TokenValidationStrategy

    public init(tokenStorage: TokenReader, validationStrategy: TokenValidationStrategy) {
        self.tokenStorage = tokenStorage
        self.validationStrategy = validationStrategy
    }

    public func intercept(_ request: URLRequest, next: HTTPClient) async throws -> (Data, HTTPURLResponse) {
        let authenticatedRequest = await addAuthHeaderIfValid(to: request)
        return try await next.send(authenticatedRequest)
    }

    private func addAuthHeaderIfValid(to request: URLRequest) async -> URLRequest {
        do {
            if let token = try await tokenStorage.loadTokenBundle(),
               validationStrategy.isValid(token)
            {
                var authenticatedRequest = request
                authenticatedRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
                return authenticatedRequest
            }
        } catch {
            _ = error
        }
        return request
    }
}
