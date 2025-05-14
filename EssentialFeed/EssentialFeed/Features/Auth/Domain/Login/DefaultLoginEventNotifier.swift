import Foundation

public final class DefaultLoginEventNotifier: LoginEventNotifier {
    private let successObserver: LoginSuccessObserver
    private let failureObserver: LoginFailureObserver

    public init(successObserver: LoginSuccessObserver, failureObserver: LoginFailureObserver) {
        self.successObserver = successObserver
        self.failureObserver = failureObserver
    }

    public func notifySuccess(response: LoginResponse) {
        successObserver.didLoginSuccessfully(response: response)
    }

    public func notifyFailure(error: Error) {
        failureObserver.didFailLogin(error: error)
    }
}
