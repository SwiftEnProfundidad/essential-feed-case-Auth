import Foundation

public final class AuthenticatedHTTPClientDecorator: HTTPClient, @unchecked Sendable {
    private let client: HTTPClient
    private let authHandler: HTTPClientAuthenticationHandler

    public init(client: HTTPClient, authHandler: HTTPClientAuthenticationHandler) {
        self.client = client
        self.authHandler = authHandler
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await authHandler.handle(request, with: client)
    }
}
