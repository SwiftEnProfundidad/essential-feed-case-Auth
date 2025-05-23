import EssentialFeed
import Foundation

public final class UserRegistrationNotifierSpy: UserRegistrationNotifier {
    private(set) var notifiedEmailInUse = false
    private(set) var notifiedConnectivityError = false
    private(set) var registrationFailedError: Error?
    public var receivedErrors: [Error] = []
    private let onNotify: (() -> Void)?
    private let onError: ((Error) -> Void)?

    init(onNotify: (() -> Void)? = nil, onError: ((Error) -> Void)? = nil) {
        self.onNotify = onNotify
        self.onError = onError
    }

    public func notifyRegistrationFailed(with error: Error) {
        registrationFailedError = error
        receivedErrors.append(error)
        onError?(error)

        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            notifiedConnectivityError = true
        }
        if let regError = error as? UserRegistrationError, regError == .emailAlreadyInUse {
            notifiedEmailInUse = true
        }
        if let networkError = error as? NetworkError, networkError == .noConnectivity {
            notifiedConnectivityError = true
        }
        onNotify?()
    }

    func wasEmailInUseNotified() -> Bool {
        notifiedEmailInUse
    }

    func wasConnectivityErrorNotified() -> Bool {
        notifiedConnectivityError
    }
}
