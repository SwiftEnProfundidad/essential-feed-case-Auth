
import EssentialFeed
import SwiftUI

public enum LoginComposer {
    public static func composedViewController(onAuthenticated: @escaping () -> Void) -> UIViewController {
        let viewModel = LoginViewModel(authenticate: { _, _ in
            // TODO: Implement real authentication logic
            .failure(LoginError.invalidCredentials)
        })

        viewModel.onAuthenticated = onAuthenticated
        let view = LoginView(viewModel: viewModel)

        return UIHostingController(rootView: view)
    }
}
