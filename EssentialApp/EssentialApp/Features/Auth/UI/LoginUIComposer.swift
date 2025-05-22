import EssentialFeed
import SwiftUI
import UIKit

public enum LoginUIComposer {
    private class LoginNavigationHandler: LoginNavigation {
        let onRecoveryRequested: () -> Void

        init(onRecoveryRequested: @escaping () -> Void) {
            self.onRecoveryRequested = onRecoveryRequested
        }

        func showRecovery() {
            onRecoveryRequested()
        }
    }

    public static func composedLoginViewController(
        with viewModel: LoginViewModel,
        onRecoveryRequested: @escaping () -> Void
    ) -> UIViewController {
        let navigationHandler = LoginNavigationHandler(onRecoveryRequested: onRecoveryRequested)
        viewModel.navigation = navigationHandler

        let swiftUIView = NavigationView {
            LoginView(viewModel: viewModel)
        }
        .navigationViewStyle(.stack)

        return UIHostingController(rootView: swiftUIView)
    }
}
