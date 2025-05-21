import Combine
import Foundation

public protocol LoginNavigation: AnyObject {
    func showRecovery()
}

public enum ViewState: Hashable {
    case idle
    case blocked
    case error(String)
    case success(String)
}

public final class LoginViewModel: ObservableObject {
    @Published public var username: String = "" {
        didSet {
            // if oldValue != username { errorMessage = nil } // MANTENER COMENTADO
        }
    }

    @Published public var password: String = "" {
        didSet {
            // if oldValue != password, errorMessage != nil { // MANTENER COMENTADO
            //     userDidInitiateEditing()
            // }
        }
    }

    @Published public var errorMessage: String?
    @Published public var loginSuccess: Bool = false
    @Published public var isLoginBlocked = false
    public let authenticated = PassthroughSubject<Void, Never>()
    public let recoveryRequested = PassthroughSubject<Void, Never>()
    private var cancellables: Set<AnyCancellable> = []
    private var delayTask: Task<Void, Never>?

    public var authenticate: (String, String) async -> Result<LoginResponse, LoginError>
    private let pendingRequestStore: AnyLoginRequestStore?
    private let loginSecurity: LoginSecurityUseCase
    private let blockMessageProvider: LoginBlockMessageProvider
    public var navigation: LoginNavigation?

    public init(
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>,
        pendingRequestStore: AnyLoginRequestStore? = nil,
        loginSecurity: LoginSecurityUseCase = LoginSecurityUseCase(),
        blockMessageProvider: LoginBlockMessageProvider = DefaultLoginBlockMessageProvider()
    ) {
        self.authenticate = authenticate
        self.pendingRequestStore = pendingRequestStore
        self.loginSecurity = loginSecurity
        self.blockMessageProvider = blockMessageProvider
        recoveryRequested
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.navigation?.showRecovery()
            }
            .store(in: &cancellables)
    }

    @MainActor
    public func login() async {
        await checkAccountUnlock(for: username)
        guard !isLoginBlocked else {
            errorMessage = blockMessageProvider.message(for: LoginError.accountLocked)
            return
        }

        guard let (trimmedUsername, trimmedPassword) = validateCredentials() else {
            return
        }

        await performAuthentication(username: trimmedUsername, password: trimmedPassword)
    }

    // MARK: - Private Helpers

    private func validateCredentials() -> (username: String, password: String)? {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty else {
            errorMessage = blockMessageProvider.message(for: LoginError.invalidEmailFormat)
            return nil
        }

        guard !trimmedPassword.isEmpty else {
            errorMessage = blockMessageProvider.message(for: LoginError.invalidPasswordFormat)
            return nil
        }

        return (trimmedUsername, trimmedPassword)
    }

    @MainActor
    private func performAuthentication(username: String, password: String) async {
        let result = await authenticate(username, password)
        errorMessage = nil

        switch result {
        case .success:
            await handleSuccessfulLogin(username: username)
        case let .failure(error):
            await handleFailedLogin(username: username, error: error)
            if case .network = error {
                savePendingRequest(username: username, password: password)
            }
        }
    }

    @MainActor
    private func handleSuccessfulLogin(username: String) async {
        await loginSecurity.resetAttempts(username: username)
        loginSuccess = true
        authenticated.send(())
        errorMessage = nil
        isLoginBlocked = false
        onAuthenticated?()
    }

    private func savePendingRequest(username: String, password: String) {
        let request = LoginRequest(username: username, password: password)
        pendingRequestStore?.save(request)
    }

    public func unlockAfterRecovery() async {
        isLoginBlocked = false
        errorMessage = nil
        await loginSecurity.resetAttempts(username: username)
    }

    private func handleFailedLogin(username: String, error: LoginError = .invalidCredentials) async {
        await loginSecurity.handleFailedLogin(username: username)

        await MainActor.run { [weak self] in
            guard let self else { return }

            if self.loginSecurity.isAccountLocked(username: username) {
                self.errorMessage = self.blockMessageProvider.message(for: LoginError.accountLocked)
                self.isLoginBlocked = true
            } else {
                self.errorMessage = self.blockMessageProvider.message(for: error)
            }
        }
    }

    private func checkAccountUnlock(for username: String) async {
        guard loginSecurity.isAccountLocked(username: username) else { return }

        if loginSecurity.getRemainingBlockTime(username: username) == nil {
            await loginSecurity.resetAttempts(username: username)
            await MainActor.run { [weak self] in
                self?.isLoginBlocked = false
                self?.errorMessage = nil
            }
        }
    }

    public var onAuthenticated: (() -> Void)?

    public func retryPendingRequests() async {
        guard let store = pendingRequestStore else { return }
        let requests = store.loadAll()
        for req in requests {
            let result = await authenticate(req.username, req.password)
            if case .success = result {
                store.remove(req)
                errorMessage = nil
                loginSuccess = true
                authenticated.send(())
            }
        }
    }

    public func onSuccessAlertDismissed() {
        loginSuccess = false
        onAuthenticated?()
    }

    public func handleRecoveryTap() {
        navigation?.showRecovery()
    }

    public func userWillBeginEditing() {
        if errorMessage != nil {
            errorMessage = nil
            objectWillChange.send()
            // Si userDidInitiateEditing() tenía más lógica relevante, considerar llamarla o moverla aquí.
            // Por ahora, nos centramos en limpiar el error para estabilizar el TextField.
        }
    }

    public func userDidInitiateEditing() {
        // Esta función ahora se llamaría explícitamente si es necesario para otras lógicas,
        // o su contenido (si es solo limpiar error) se integra en userWillBeginEditing.
        // Por ahora, la dejamos así, pero no se llamará desde didSet de password.
        debugPrint("LoginViewModel: userDidInitiateEditing - Clearing error message if present.")
        if errorMessage != nil {
            errorMessage = nil
        }
        debugPrint("LoginViewModel: userDidInitiateEditing - Error message after attempting to clear: \(errorMessage ?? "nil")")
    }

    // MARK: - Navigation

    public var viewState: ViewState {
        if isLoginBlocked {
            .blocked
        } else if let message = errorMessage {
            .error(message)
        } else if loginSuccess {
            // Puedes personalizar el mensaje de éxito si es necesario
            .success("Login successful!")
        } else {
            .idle
        }
    }

    deinit {
        delayTask?.cancel()
    }
}

extension LoginViewModel: LoginViewModelProtocol {}
