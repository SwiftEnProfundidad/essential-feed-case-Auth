
import EssentialFeed
import SwiftUI

public enum LoginUIComposer {
    public static func composedLoginViewController(with viewModel: LoginViewModel, onRecoveryRequested _: @escaping () -> Void = {}) -> UIViewController {
        let loginView = LoginView(viewModel: viewModel)
        return UIHostingController(rootView: loginView)
    }
}
