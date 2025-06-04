import Foundation

public protocol AuthenticationHandler {
    func requiresAuthentication(_ request: URLRequest) -> Bool
    func addToken(_ token: String, to request: URLRequest) -> URLRequest
    func isUnauthorizedError(_ error: Error) -> Bool
}

public final class DefaultAuthenticationHandler: AuthenticationHandler {
    private let publicPaths: Set<String>

    public init(publicPaths: Set<String> = ["/public/"]) {
        self.publicPaths = publicPaths
    }

    public func requiresAuthentication(_ request: URLRequest) -> Bool {
        guard let path = request.url?.path else { return true }
        return !publicPaths.contains { path.hasPrefix($0) }
    }

    public func addToken(_ token: String, to request: URLRequest) -> URLRequest {
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return authenticatedRequest
    }

    public func isUnauthorizedError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .userAuthenticationRequired ||
                urlError.code == .userCancelledAuthentication ||
                urlError.errorCode == 401
        }
        return false
    }
}
