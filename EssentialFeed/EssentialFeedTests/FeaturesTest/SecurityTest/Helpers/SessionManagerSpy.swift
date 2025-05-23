import EssentialFeed
import Foundation

final class SessionManagerSpy: SessionManagerProtocol, @unchecked Sendable {
    private let lock = NSRecursiveLock()

    private var _refreshCalls = 0
    private var _endRefreshingCalls = 0
    private var _logoutCalls = 0

    var refreshCalls: Int {
        lock.lock()
        defer { lock.unlock() }
        return _refreshCalls
    }

    var endRefreshingCalls: Int {
        lock.lock()
        defer { lock.unlock() }
        return _endRefreshingCalls
    }

    var logoutCalls: Int {
        lock.lock()
        defer { lock.unlock() }
        return _logoutCalls
    }

    var isRefreshing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _refreshCalls > _endRefreshingCalls
    }

    func startRefreshing() {
        lock.lock()
        _refreshCalls += 1
        lock.unlock()
    }

    func endRefreshing() {
        lock.lock()
        _endRefreshingCalls += 1
        lock.unlock()
    }

    func logout() {
        lock.lock()
        _logoutCalls += 1
        lock.unlock()
    }
}
