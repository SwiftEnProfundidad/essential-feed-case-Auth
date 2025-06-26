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

    @Published public private(set) var isPerformingLogin: Bool = false

    @Published public private(set) var publishedViewState: ViewState = .idle
    @Published public var shouldShowCaptcha: Bool = false {
        didSet { updateViewState() }
    }

    @Published public var captchaToken: String? = nil {
        didSet { updateViewState() }
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
            errorMessage = blockMessageProvider.message(
                for: LoginError.accountLocked(remainingTime: Int(remainingTime)))
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
        guard let coordinator = captchaFlowCoordinator else { return }
        guard let token = captchaToken else { return }
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = await coordinator.handleCaptchaValidation(token: token, username: trimmedUsername)

        switch result {
        case .success:
            shouldShowCaptcha = false
            errorMessage = nil
            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

            await loginSecurity.resetAttempts(username: trimmedUsername)

            await performAuthentication(
                username: trimmedUsername,
                password: trimmedPassword,
                isPostCaptchaRetry: true
            )
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
            "Network error during CAPTCHA. Please check connection."
        case .malformedRequest:
            "CAPTCHA verification error. Please refresh and try again."
        case .serviceUnavailable:
            "CAPTCHA service is currently unavailable. Please try again later."
        case .rateLimitExceeded:
            "You have made too many requests. Please try again later."
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
    private func performAuthentication(
        username: String, password: String, isPostCaptchaRetry: Bool = false
    ) async {
        isPerformingLogin = true
        let authResult = await authenticate(username, password)

        switch authResult {
        case .success:
            await handleSuccessfulLogin(username: username)
        case let .failure(error):
            await handleFailedLogin(error, for: username, isPostCaptchaRetry: isPostCaptchaRetry)
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
        isPerformingLogin = false
        resetCaptchaState()
    }

    private func savePendingRequest(username: String, password: String) {
        let request = LoginRequest(username: username, password: password)
        pendingRequestStore?.save(request)
    }

    @MainActor
    private func handleFailedLogin(_ error: LoginError, for username: String, isPostCaptchaRetry: Bool = false) async {
        isPerformingLogin = false

        if isPostCaptchaRetry {
            self.errorMessage = nil
            resetCaptchaState()
            updateViewState()
            return
        }

        await loginSecurity.handleFailedLogin(username: username)
        if let coordinator = captchaFlowCoordinator {
            let attempts = loginSecurity.getFailedAttempts(username: username)
            shouldShowCaptcha = coordinator.shouldTriggerCaptcha(failedAttempts: attempts)
        }

        if await loginSecurity.isAccountLocked(username: username) {
            let remainingTime = loginSecurity.getRemainingBlockTime(username: username) ?? 0
            self.errorMessage = blockMessageProvider.message(
                for: LoginError.accountLocked(remainingTime: Int(remainingTime)))
            isLoginBlocked = true
        } else {
            self.errorMessage = mapLoginError(error, for: username)
        }

        updateViewState()
    }

    @MainActor
    private func checkAccountUnlock(for username: String) async {
        let isLocked = await loginSecurity.isAccountLocked(username: username)
        if isLocked {
            let remainingTime = loginSecurity.getRemainingBlockTime(username: username) ?? 0
            errorMessage = blockMessageProvider.message(
                for: LoginError.accountLocked(remainingTime: Int(remainingTime)))
            isLoginBlocked = true
            shouldShowCaptcha = true
        } else {
            isLoginBlocked = false
            let accountLockedErrorExample = LoginError.accountLocked(remainingTime: 0)
            if let currentErrorMessage = errorMessage,
               currentErrorMessage.contains("locked"),
               currentErrorMessage.contains(
                   blockMessageProvider.message(for: accountLockedErrorExample).prefix(10))
            {
                errorMessage = nil
            }
        }
    }

    public var onAuthenticated: (() -> Void)?

    public func retryPendingRequests() async {
        guard let store = pendingRequestStore else { return }
        let requests = store.loadAll()
        for req in requests {
            let authResult = await authenticate(req.username, req.password)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if case .failure = authResult {
                } else {
                    store.remove(req)
                }
                self.errorMessage = nil
                self.loginSuccess = true
                self.authenticated.send(())
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
        if shouldShowCaptcha, let message = errorMessage {
            publishedViewState = .error(message)
        } else if isLoginBlocked {
            let messageToDisplay =
                errorMessage
                    ?? blockMessageProvider.message(
                        for: LoginError.accountLocked(
                            remainingTime: Int(loginSecurity.getRemainingBlockTime(username: username) ?? 0)))
            publishedViewState = .error(messageToDisplay)
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

    private func mapLoginError(_ error: LoginError, for _: String) -> String {
        switch error {
        case .invalidCredentials:
            "Invalid username or password."
        case let .accountLocked(remainingTime):
            blockMessageProvider.message(for: LoginError.accountLocked(remainingTime: remainingTime))
        case .network:
            "A network error occurred. Please try again."
        case .invalidEmailFormat,
             .invalidPasswordFormat,
             .tokenStorageFailed,
             .noConnectivity,
             .offlineStoreFailed,
             .messageForMaxAttemptsReached,
             .unknown:
            error.errorMessage()
        }
    }
}

extension LoginViewModel: LoginViewModelProtocol {
    public func unlockAfterRecovery() async {
        await loginSecurity.resetAttempts(username: username)
        isLoginBlocked = false
        errorMessage = nil
        shouldShowCaptcha = false
        updateViewState()
    }
}

extension LoginViewModel: CaptchaStateManaging {
    public func setCaptchaRequired(_ required: Bool) {
        shouldShowCaptcha = required
    }

    public func setCaptchaToken(_ token: String?) {
        self.captchaToken = token

        if token != nil {
            Task { @MainActor in
                await validateCaptchaAndProceed()
            }
        }
    }

    public func resetCaptchaState() {
        shouldShowCaptcha = false
        captchaToken = nil
    }
}
