import Foundation

public protocol SessionUserDefaultsCleaning {
    func clearSessionData() async throws
}
