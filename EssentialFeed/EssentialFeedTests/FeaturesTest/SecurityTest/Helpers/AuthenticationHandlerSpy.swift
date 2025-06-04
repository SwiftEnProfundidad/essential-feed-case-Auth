import EssentialFeed
import Foundation

public final class AuthenticationHandlerSpy: AuthenticationHandler {
    public enum Message: Equatable {
        case requiresAuthentication(URLRequest)
        case addToken(String, URLRequest)
        case isUnauthorizedError(String)
    }

    public private(set) var messages: [Message] = []

    public var requiresAuthenticationResult: Bool = true
    public var isUnauthorizedErrorResult: Bool = false

    public init() {}

    public func requiresAuthentication(_ request: URLRequest) -> Bool {
        messages.append(.requiresAuthentication(request))
        return requiresAuthenticationResult
    }

    public func addToken(_ token: String, to request: URLRequest) -> URLRequest {
        messages.append(.addToken(token, request))
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return authenticatedRequest
    }

    public func isUnauthorizedError(_ error: Error) -> Bool {
        messages.append(.isUnauthorizedError(error.localizedDescription))
        return isUnauthorizedErrorResult
    }
}
