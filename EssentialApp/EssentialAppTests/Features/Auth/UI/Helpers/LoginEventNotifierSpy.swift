import EssentialFeed
import Foundation

class LoginEventNotifierSpy: LoginEventNotifier {
    private let successObserver: LoginSuccessObserver
    private let failureObserver: LoginFailureObserver

    private(set) var notifySuccessCalls: [LoginResponse] = []
    private(set) var notifyFailureCalls: [Error] = []

    init(successObserver: LoginSuccessObserver, failureObserver: LoginFailureObserver) {
        self.successObserver = successObserver
        self.failureObserver = failureObserver
    }

    func notifySuccess(response: LoginResponse) {
        notifySuccessCalls.append(response)
        successObserver.didLoginSuccessfully(response: response)
    }

    func notifyFailure(error: Error) {
        notifyFailureCalls.append(error)
        failureObserver.didFailLogin(error: error)
    }
}
