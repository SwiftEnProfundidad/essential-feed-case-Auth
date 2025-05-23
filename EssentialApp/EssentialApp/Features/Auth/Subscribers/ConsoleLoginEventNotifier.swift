import EssentialFeed
import Foundation

class ConsoleLoginEventNotifier: LoginEventNotifier {
    func notifySuccess(response: LoginResponse) {
        // Accedemos directamente a response.token ya que es un String
        print("Notifier: Login successful for token: \(response.token.prefix(10))...")
    }

    func notifyFailure(error: Error) {
        print("Notifier: Login failed with error: \(error)")
    }
}
