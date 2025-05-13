import EssentialFeed
import Foundation

final class UserRegistrationNotifierSpy: UserRegistrationNotifier {
    private(set) var receivedErrors = [Error]()

    var notifiedEmailInUse: Bool {
        receivedErrors.contains { ($0 as? UserRegistrationError) == .emailAlreadyInUse }
    }

    var notifiedConnectivityError: Bool {
        receivedErrors.contains { ($0 as? NetworkError) == .noConnectivity }
    }

    var wasNotified: Bool {
        !receivedErrors.isEmpty
    }

    private let onNotify: (() -> Void)?

    init(onNotify: (() -> Void)? = nil) {
        self.onNotify = onNotify
    }

    func notifyRegistrationFailed(with error: Error) {
        receivedErrors.append(error)
        if (error as? UserRegistrationError) == .emailAlreadyInUse {
            onNotify?()
        }
    }
}
