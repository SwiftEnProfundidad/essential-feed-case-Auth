import Foundation

public enum HTTPClientAuthenticationHandlerFactory {
    public static func make(
        tokenStorage: TokenStorage,
        refreshTokenUseCase: RefreshTokenUseCase,
        logoutManager: SessionLogoutManager,
        validationStrategy: TokenValidationStrategy = ExpiryTokenValidationStrategy(),
        routePolicy: RouteAuthenticationPolicy = PathBasedRoutePolicy()
    ) -> HTTPClientAuthenticationHandler {
        DefaultHTTPClientAuthenticationHandler(
            tokenStorage: tokenStorage,
            refreshTokenUseCase: refreshTokenUseCase,
            logoutManager: logoutManager,
            validationStrategy: validationStrategy,
            routePolicy: routePolicy
        )
    }
}
