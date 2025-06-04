import Foundation

public enum SessionError: Error {
    case tokenRefreshFailed
    case globalLogoutRequired
}

public final class AuthenticatedHTTPClientDecorator: HTTPClient, @unchecked Sendable {
    private let interceptorChain: InterceptorChain

    public init(
        client: HTTPClient,
        tokenStorage: TokenStorage,
        refreshTokenUseCase: RefreshTokenUseCase,
        logoutManager: SessionLogoutManager,
        validationStrategy: TokenValidationStrategy = ExpiryTokenValidationStrategy(),
        routePolicy: RouteAuthenticationPolicy = PathBasedRoutePolicy()
    ) {
        let interceptors: [HTTPClientInterceptor] = [
            RouteAuthenticationInterceptor(routePolicy: routePolicy),
            TokenValidationInterceptor(tokenStorage: tokenStorage, validationStrategy: validationStrategy),
            TokenRefreshInterceptor(refreshTokenUseCase: refreshTokenUseCase, tokenStorage: tokenStorage),
            GlobalLogoutInterceptor(logoutManager: logoutManager)
        ]

        self.interceptorChain = InterceptorChain(interceptors: interceptors, baseClient: client)
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await interceptorChain.send(request)
    }
}
