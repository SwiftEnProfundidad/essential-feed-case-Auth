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
        viewModel.onAuthenticated = onAuthenticated
        let loginView = LoginView(viewModel: viewModel)
        let controller = UIHostingController(rootView: loginView)
        return controller
    }
}
