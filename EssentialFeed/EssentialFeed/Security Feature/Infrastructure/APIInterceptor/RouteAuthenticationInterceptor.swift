import Foundation

public final class RouteAuthenticationInterceptor: HTTPClientInterceptor {
    private let routePolicy: RouteAuthenticationPolicy

    public init(routePolicy: RouteAuthenticationPolicy) {
        self.routePolicy = routePolicy
    }

    public func intercept(_ request: URLRequest, next: HTTPClient) async throws -> (Data, HTTPURLResponse) {
        guard routePolicy.requiresAuthentication(request) else {
            return try await next.send(request)
        }

        return try await next.send(request)
    }
}
