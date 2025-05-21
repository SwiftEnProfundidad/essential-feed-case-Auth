import EssentialFeed
import SwiftUI

public enum LoginUIComposer {
    public static func composedLoginViewController(with viewModel: LoginViewModel, onRecoveryRequested: @escaping () -> Void) -> UIViewController {
        let adapter = LoginNavigationAdapter(onRecoveryRequested: onRecoveryRequested)
        viewModel.navigation = adapter

        let loginView = LoginView(viewModel: viewModel)
        return UIHostingController(rootView: loginView)
    }
}

private class LoginNavigationAdapter: LoginNavigation {
    private let onRecoveryRequested: () -> Void

    init(onRecoveryRequested: @escaping () -> Void) {
        self.onRecoveryRequested = onRecoveryRequested
    }

    func showRecovery() {
        onRecoveryRequested()
    }
}
