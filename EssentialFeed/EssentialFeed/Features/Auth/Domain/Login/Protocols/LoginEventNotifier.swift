import Foundation

public protocol LoginEventNotifier {
    func notifySuccess(response: LoginResponse)
    func notifyFailure(error: Error)
}
