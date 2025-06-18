import EssentialFeed
import SwiftUI
import UIKit

public final class BasicRegistrationFlowHandler: RegistrationNavigation {
    private weak var presentingViewController: UIViewController?

    public init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
    }

    public func showLogin() {
        presentingViewController?.dismiss(animated: true)
    }
}

public enum RegistrationComposer {
    @MainActor public static func registrationViewController() -> UIViewController {
        let httpClient = NetworkDependencyFactory.makeHTTPClient()
        let registrationAPI = HTTPUserRegistrationAPI(client: httpClient)
        let tokenStorage = KeychainDependencyFactory.makeTokenStorage()
        let offlineStore = InMemoryOfflineRegistrationStore()

        let registrationService = DefaultRegistrationService(
            registrationAPI: registrationAPI,
            tokenStorage: tokenStorage,
            offlineStore: offlineStore
        )

        let userRegistrationUseCase = UserRegistrationUseCase(registrationService: registrationService)
        let viewModel = RegistrationViewModel(userRegisterer: userRegistrationUseCase)
        let registrationView = RegistrationView(viewModel: viewModel)

        let hostingController = UIHostingController(rootView: registrationView)
        let navigationHandler = BasicRegistrationFlowHandler(presentingViewController: hostingController)
        viewModel.navigation = navigationHandler

        return hostingController
    }
}
