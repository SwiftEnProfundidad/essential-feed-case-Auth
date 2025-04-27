import UIKit
import SwiftUI
import Combine
import EssentialFeed

public enum LoginComposer {
    private static var cancellables = Set<AnyCancellable>()
    public static func loginViewController(
        onAuthenticated: @escaping () -> Void) -> UIViewController {
        print("🛠 LoginComposer: loginViewController called")
        let viewModel = LoginViewModel()
        let loginView = LoginView(viewModel: viewModel)
        let controller = UIHostingController(rootView: loginView)
        viewModel.authenticated
            .sink {
                print("🔔 LoginComposer: authenticated publisher fired")
                onAuthenticated()
            }
            .store(in: &cancellables)
        return controller
    }
}
