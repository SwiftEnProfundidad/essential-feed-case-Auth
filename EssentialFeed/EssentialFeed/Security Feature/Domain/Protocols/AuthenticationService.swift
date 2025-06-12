import Foundation

public protocol AuthenticationService {
    func authenticateRequest(_ request: URLRequest) async -> URLRequest
    func handleAuthenticationFailure(for request: URLRequest) async throws -> URLRequest
}
