import EssentialFeed
import SwiftUI
import UIKit

public enum LoginUIComposer {
    private class LoginNavigationHandler: LoginNavigation {
        let onRecoveryRequested: () -> Void
        let onRegisterRequested: () -> Void

        init(onRecoveryRequested: @escaping () -> Void, onRegisterRequested: @escaping () -> Void = {}) {
            self.onRecoveryRequested = onRecoveryRequested
            self.onRegisterRequested = onRegisterRequested
        }

        func showRecovery() {
            onRecoveryRequested()
        }

        func showRegister() {
            onRegisterRequested()
        }
    }

    public static func composedLoginViewController(
        with viewModel: LoginViewModel,
        onRecoveryRequested: @escaping () -> Void,
        onRegisterRequested: @escaping () -> Void = {}
    ) -> UIViewController {
        let navigationHandler = LoginNavigationHandler(onRecoveryRequested: onRecoveryRequested, onRegisterRequested: onRegisterRequested)
        viewModel.navigation = navigationHandler

        let swiftUIView = NavigationView {
            LoginView(viewModel: viewModel)
        }
        .navigationViewStyle(.stack)

        return UIHostingController(rootView: swiftUIView)
    }
}
