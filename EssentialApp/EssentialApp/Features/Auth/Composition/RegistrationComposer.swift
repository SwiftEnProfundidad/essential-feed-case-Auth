import EssentialFeed
import SwiftUI
import UIKit

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

        return UIHostingController(rootView: registrationView)
    }
}
