import EssentialFeed
import Foundation

extension TokenRefreshResult {
    func toData() -> Data {
        let components = [accessToken, refreshToken, "\(expiry.timeIntervalSince1970)"]
        return components.joined(separator: ",").data(using: .utf8)!
    }
}
