import EssentialFeed
import Foundation

class LoginFailureObserverSpy: LoginFailureObserver {
    private(set) var notificationCount = 0
    private(set) var lastError: Error?

    func didFailLogin(error: Error) {
        notificationCount += 1
        lastError = error
    }
}
