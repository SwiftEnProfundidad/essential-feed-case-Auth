import Combine
import Foundation

public protocol LoginNavigation: AnyObject {
    func showRecovery()
    func showRegister()
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
            if oldValue != username { errorMessage = nil }
        }
    }

    @Published public var password: String = "" {
        didSet {
            if oldValue != password, errorMessage != nil {
                userDidInitiateEditing()
            }
        }
    }

    @Published public var errorMessage: String? {
        didSet { updateViewState() }
    }

    @Published public var loginSuccess: Bool = false {
        didSet { updateViewState() }
    }

    @Published public var isLoginBlocked = false {
        didSet { updateViewState() }
    }

    @Published public private(set) var publishedViewState: ViewState = .idle
    @Published public var shouldShowCaptcha: Bool = false {
        didSet { updateViewState() }
    }

    @Published public var captchaToken: String? {
        didSet {
            if captchaToken != nil, shouldShowCaptcha {
                Task { await validateCaptchaAndProceed() }
            }
        }
    }

    public let authenticated = PassthroughSubject<Void, Never>()
    public let recoveryRequested = PassthroughSubject<Void, Never>()
    public let registerRequested = PassthroughSubject<Void, Never>()
    private var cancellables: Set<AnyCancellable> = []
    private var delayTask: Task<Void, Never>?

    public var authenticate: (String, String) async -> Result<LoginResponse, LoginError>
    private let pendingRequestStore: AnyLoginRequestStore?
    private let loginSecurity: LoginSecurityUseCase
    private let blockMessageProvider: LoginBlockMessageProvider
    private let captchaFlowCoordinator: CaptchaFlowCoordinating?
    public var navigation: LoginNavigation?

    public init(
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>,
        pendingRequestStore: AnyLoginRequestStore? = nil,
        loginSecurity: LoginSecurityUseCase = LoginSecurityUseCase(),
        blockMessageProvider: LoginBlockMessageProvider = DefaultLoginBlockMessageProvider(),
        captchaFlowCoordinator: CaptchaFlowCoordinating? = nil
    ) {
        self.authenticate = authenticate
        self.pendingRequestStore = pendingRequestStore
        self.loginSecurity = loginSecurity
        self.blockMessageProvider = blockMessageProvider
        self.captchaFlowCoordinator = captchaFlowCoordinator
        recoveryRequested
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.navigation?.showRecovery()
            }
            .store(in: &cancellables)

        registerRequested
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.navigation?.showRegister()
            }
            .store(in: &cancellables)
    }

    @MainActor
    public func login() async {
        await checkAccountUnlock(for: username)

        if isLoginBlocked {
            let remainingTime = loginSecurity.getRemainingBlockTime(username: username) ?? 0
            errorMessage = blockMessageProvider.message(for: LoginError.accountLocked(remainingTime: Int(remainingTime)))
            return
        }

        guard let (trimmedUsername, trimmedPassword) = validateCredentials() else {
            return
        }

        if shouldShowCaptcha, captchaToken == nil {
            errorMessage = "Please complete the CAPTCHA verification"
            return
        }

        await performAuthentication(username: trimmedUsername, password: trimmedPassword)
    }

    @MainActor
    private func validateCaptchaAndProceed() async {
        guard let token = captchaToken,
              let coordinator = captchaFlowCoordinator else { return }

        let result = await coordinator.handleCaptchaValidation(token: token, username: username)

        switch result {
        case .success:
            shouldShowCaptcha = false
            errorMessage = nil
            guard let (trimmedUsername, trimmedPassword) = validateCredentials() else { return }
            await performAuthentication(username: trimmedUsername, password: trimmedPassword)
        case let .failure(error):
            captchaToken = nil
            errorMessage = mapCaptchaError(error)
        }
    }

    private func mapCaptchaError(_ error: CaptchaError) -> String {
        switch error {
        case .invalidResponse:
            "CAPTCHA verification failed. Please try again."
        case .networkError:
            "Network error during CAPTCHA verification. Please try again."
        case .serviceUnavailable:
            "CAPTCHA service temporarily unavailable. Please try again later."
        case .rateLimitExceeded:
            "Too many CAPTCHA attempts. Please wait before trying again."
        case .malformedRequest:
            "CAPTCHA verification error. Please refresh and try again."
        case let .unknownError(message):
            "CAPTCHA error: \(message)"
        }
    }

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
        shouldShowCaptcha = false
        captchaToken = nil
        onAuthenticated?()
    }

    private func savePendingRequest(username: String, password: String) {
        let request = LoginRequest(username: username, password: password)
        pendingRequestStore?.save(request)
    }

    public func unlockAfterRecovery() async {
        isLoginBlocked = false
        errorMessage = nil
        shouldShowCaptcha = false
        captchaToken = nil
        await loginSecurity.resetAttempts(username: username)
    }

    @MainActor
    private func handleFailedLogin(username: String, error: LoginError = .invalidCredentials) async {
        await loginSecurity.handleFailedLogin(username: username)

        let isLocked = await loginSecurity.isAccountLocked(username: username)
        if isLocked {
            let remainingTime = loginSecurity.getRemainingBlockTime(username: username) ?? 0
            self.errorMessage = self.blockMessageProvider.message(for: LoginError.accountLocked(remainingTime: Int(remainingTime)))
            self.isLoginBlocked = true
            self.shouldShowCaptcha = false
        } else {
            let failedAttempts = loginSecurity.getFailedAttempts(username: username)

            if let coordinator = captchaFlowCoordinator,
               coordinator.shouldTriggerCaptcha(failedAttempts: failedAttempts)
            {
                self.shouldShowCaptcha = true
                self.captchaToken = nil
                self.errorMessage = "Please complete CAPTCHA verification to continue"
            } else {
                self.errorMessage = self.blockMessageProvider.message(for: error)
                self.shouldShowCaptcha = false
            }

            self.isLoginBlocked = false
        }
    }

    @MainActor
    private func checkAccountUnlock(for username: String) async {
        let isLocked = await loginSecurity.isAccountLocked(username: username)
        if isLocked {
            let remainingTime = loginSecurity.getRemainingBlockTime(username: username) ?? 0
            errorMessage = blockMessageProvider.message(for: LoginError.accountLocked(remainingTime: Int(remainingTime)))
            isLoginBlocked = true
            shouldShowCaptcha = false
        } else {
            isLoginBlocked = false
            if errorMessage?.contains("locked") == true {
                errorMessage = nil
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
        recoveryRequested.send(())
    }

    public func handleRegisterTap() {
        registerRequested.send(())
    }

    public func userDidInitiateEditing() {
        if errorMessage != nil {
            errorMessage = nil
        }
    }

    public var viewState: ViewState {
        if isLoginBlocked {
            .blocked
        } else if let message = errorMessage {
            .error(message)
        } else if loginSuccess {
            .success("Login successful!")
        } else {
            .idle
        }
    }

    private func updateViewState() {
        if isLoginBlocked {
            publishedViewState = .blocked
        } else if let message = errorMessage {
            publishedViewState = .error(message)
        } else if loginSuccess {
            publishedViewState = .success("Login successful!")
        } else {
            publishedViewState = .idle
        }
    }

    deinit {
        delayTask?.cancel()
    }
}

extension LoginViewModel: LoginViewModelProtocol {}

extension LoginViewModel: CaptchaStateManaging {
    public func setCaptchaRequired(_ required: Bool) {
        shouldShowCaptcha = required
    }

    public func setCaptchaToken(_ token: String?) {
        captchaToken = token
    }

    public func resetCaptchaState() {
        shouldShowCaptcha = false
        captchaToken = nil
    }
}
