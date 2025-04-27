import Foundation
import Combine

public final class LoginViewModel: ObservableObject {
    @Published public var username: String = ""
    @Published public var password: String = ""
    @Published public var errorMessage: String?
    @Published public var loginSuccess: Bool = false
    public let authenticated = PassthroughSubject<Void, Never>()

    /// Closure de autenticación asíncrona (production y tests)
    private let authenticate: (String, String) async -> Result<LoginResponse, LoginError>

    public init(authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>) {
        self.authenticate = authenticate
    }

    @MainActor
    public func login() async {
        let result = await authenticate(username, password)
        switch result {
        case .success:
            errorMessage = nil
            loginSuccess = true
            authenticated.send(())
        case .failure(let error):
            errorMessage = error.localizedDescription
            loginSuccess = false
        }
    }
    
    public var onAuthenticated: (() -> Void)?

    public func onSuccessAlertDismissed() {
        loginSuccess = false
        onAuthenticated?()
    }
}
