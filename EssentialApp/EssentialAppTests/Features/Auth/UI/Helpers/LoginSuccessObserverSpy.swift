import EssentialFeed
import Foundation

class LoginSuccessObserverSpy: LoginSuccessObserver {
    private(set) var notificationCount = 0
    private(set) var lastResponse: LoginResponse?

    func didLoginSuccessfully(response: LoginResponse) {
        notificationCount += 1
        lastResponse = response
    }
}
