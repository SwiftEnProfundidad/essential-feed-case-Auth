import Foundation

public final class DefaultTokenRefreshService: TokenRefreshService {
    private actor RefreshActor {
        private var isRefreshingValue: Bool = false
        func getRefreshing() -> Bool { isRefreshingValue }
        func setRefreshing(_ value: Bool) { isRefreshingValue = value }
    }

    private let refreshActor = RefreshActor()
    private let maxRetries: Int
    private let minBackoffSeconds: Double

    public init(maxRetries: Int = 3, minBackoffSeconds: Double = 0.5) {
        self.maxRetries = maxRetries
        self.minBackoffSeconds = minBackoffSeconds
    }

    public func refreshToken(refreshToken _: String) async -> Result<TokenRefreshResult, TokenRefreshError> {
        if await refreshActor.getRefreshing() {
            try? await Task.sleep(nanoseconds: 100_000_000)
            return .failure(.unknown)
        }
        await refreshActor.setRefreshing(true)
        defer { Task { await refreshActor.setRefreshing(false) } }

        var lastError: TokenRefreshError = .unknown

        for attempt in 1 ... maxRetries {
            do {
                // PLACEHOLDER: Aquí iría la llamada real a la API.
                if attempt < maxRetries {
                    throw TokenRefreshError.network
                }
                let expiry = Date().addingTimeInterval(3600)
                let result = TokenRefreshResult(accessToken: "newAccessToken", refreshToken: "newRefreshToken", expiry: expiry)
                return .success(result)
            } catch let error as TokenRefreshError {
                lastError = error
                let delay = minBackoffSeconds * pow(2, Double(attempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            } catch {
                lastError = .unknown
                continue
            }
        }
        return .failure(lastError)
    }
}
