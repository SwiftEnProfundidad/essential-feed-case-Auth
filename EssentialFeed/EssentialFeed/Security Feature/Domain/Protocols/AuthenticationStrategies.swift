import Foundation

// MARK: - Token Validation Strategy

public protocol TokenValidationStrategy {
    func isValid(_ token: Token) -> Bool
}

public struct ExpiryTokenValidationStrategy: TokenValidationStrategy {
    public init() {}

    public func isValid(_ token: Token) -> Bool {
        token.expiry > Date()
    }
}

// MARK: - Route Authentication Policy

public protocol RouteAuthenticationPolicy {
    func requiresAuthentication(_ request: URLRequest) -> Bool
}

public struct PathBasedRoutePolicy: RouteAuthenticationPolicy {
    public init() {}

    public func requiresAuthentication(_ request: URLRequest) -> Bool {
        guard let path = request.url?.path else { return true }
        return !path.hasPrefix("/public/")
    }
}
