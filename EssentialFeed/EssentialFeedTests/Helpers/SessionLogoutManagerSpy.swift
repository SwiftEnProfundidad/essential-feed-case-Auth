import EssentialFeed
import Foundation
import XCTest

public actor SessionLogoutManagerSpy: SessionLogoutManager {
    private var _performGlobalLogoutCallCount = 0
    private var _stubbedPerformGlobalLogoutError: Error?

    public var performGlobalLogoutCallCount: Int {
        _performGlobalLogoutCallCount
    }

    public func completePerformGlobalLogout(with result: Result<Void, Error>) {
        switch result {
        case .success:
            _stubbedPerformGlobalLogoutError = nil
        case let .failure(error):
            _stubbedPerformGlobalLogoutError = error
        }
    }

    public init() {}

    public func performGlobalLogout() async throws {
        _performGlobalLogoutCallCount += 1
        if let error = _stubbedPerformGlobalLogoutError {
            throw error
        }
    }
}
