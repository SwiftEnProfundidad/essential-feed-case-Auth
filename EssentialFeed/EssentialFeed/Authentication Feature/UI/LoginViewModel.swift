import Foundation
import Combine

public final class LoginViewModel: ObservableObject {
    @Published public var username: String = "" {
        didSet {
            if oldValue != username { errorMessage = nil }
        }
    }
    @Published public var password: String = "" {
        didSet {
            if oldValue != password { errorMessage = nil }
        }
    }
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
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = LoginErrorMessageMapper.message(for: .invalidEmailFormat)
            loginSuccess = false
            return
        }
        guard !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = LoginErrorMessageMapper.message(for: .invalidPasswordFormat)
            loginSuccess = false
            return
        }
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = await authenticate(trimmedUsername, password)
        switch result {
        case .success:
            errorMessage = nil
            loginSuccess = true
            authenticated.send(())
        case .failure(let error):
            errorMessage = LoginErrorMessageMapper.message(for: error)
            loginSuccess = false
        }
    }
    
    public var onAuthenticated: (() -> Void)?

    public func onSuccessAlertDismissed() {
        loginSuccess = false
        onAuthenticated?()
    }
}
