import EssentialFeed
import Foundation

final class SessionUserDefaultsSpy: SessionUserDefaultsCleaning {
    enum Message: Equatable {
        case clearSessionData
    }

    private(set) var messages = [Message]()
    var clearSessionDataError: Error?

    func clearSessionData() async throws {
        messages.append(.clearSessionData)
        if let error = clearSessionDataError {
            throw error
        }
    }
}
