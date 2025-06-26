import Combine
import Foundation

public protocol LoginNavigation: AnyObject {
    func showRecovery()
    func showRegister()
}

public extension LoginViewModel {
    enum ViewState: Equatable {
        case idle
        case blocked
        case error(String)
        case success(String)
        case showingNotification(InAppNotification)

        public var isSuccess: Bool {
            switch self {
            case .success:
                true
            case let .showingNotification(notification):
                notification.type == .success
            default:
                false
            }
        }

        public var isError: Bool {
            switch self {
            case .blocked, .error:
                true
            case let .showingNotification(notification):
                notification.type == .error
            default:
                false
            }
        }
    }
}

public final class LoginViewModel: ObservableObject {
    @Published public var username: String = "" {
        didSet {
            if oldValue != username { clearNotification() }
        }
    }

    @Published public var password: String = "" {
        didSet {
            if oldValue != password, _errorMessage != nil {
                userDidInitiateEditing()
            }
        }
    }

    @Published private var _errorMessage: String?

    public var errorMessage: String? {
        get {
            if let notification = currentNotification, notification.type == .error {
                return notification.message
            }
            return _errorMessage
        }
        set {
            _errorMessage = newValue
            if newValue == nil {
                if let notification = currentNotification, notification.type == .error {
                    currentNotification = nil
                }
            }
            updateViewState()
        }
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

    @Published public var captchaToken: String? {
        didSet {
            if captchaToken != nil {
                Task {
                    await validateCaptchaAndProceed()
                }
            }
        }
    }

    @Published public var currentNotification: InAppNotification? {
        didSet { updateViewState() }
    }

    public var onAuthenticated: (() -> Void)?
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
    }

    @MainActor
    public func login() async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty, !trimmedPassword.isEmpty else {
            showErrorNotification(title: "Validation Error", message: "Please enter both username and password")
            return
        }

        if await loginSecurity.isAccountLocked(username: trimmedUsername) {
            let remainingTime = loginSecurity.getRemainingBlockTime(username: trimmedUsername) ?? 0
            let message = blockMessageProvider.message(
                for: LoginError.accountLocked(remainingTime: Int(remainingTime)))
            showErrorNotification(title: "Account Locked", message: message)
            isLoginBlocked = true
            return
        } else {
            isLoginBlocked = false
        }

        if shouldShowCaptcha, captchaToken == nil {
            showErrorNotification(title: "CAPTCHA Required", message: "Please complete the CAPTCHA verification")
            return
        }

        await performAuthentication(username: trimmedUsername, password: trimmedPassword)
    }

    private func showSuccessNotification(title: String, message: String) {
        currentNotification = InAppNotification(
            title: title,
            message: message,
            type: .success,
            actionButton: "Continue"
        )
    }

    private func showErrorNotification(title: String, message: String) {
        currentNotification = InAppNotification(
            title: title,
            message: message,
            type: .error,
            actionButton: "OK"
        )
    }

    private func clearNotification() {
        currentNotification = nil
        _errorMessage = nil
    }

    public func dismissNotification() {
        currentNotification = nil
        if loginSuccess {
            onAuthenticated?()
        }
    }

    @MainActor
    public func retryPendingRequests() async {
        guard let store = pendingRequestStore else { return }

        let pendingRequests = store.loadAll()
        for request in pendingRequests {
            let result = await authenticate(request.username, request.password)
            if case .success = result {
                await handleSuccessfulLogin(username: request.username)
                store.remove(request)
                break
            }
        }
    }

    @MainActor
    private func validateCaptchaAndProceed() async {
        guard let coordinator = captchaFlowCoordinator else { return }
        guard let token = captchaToken else { return }
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = await coordinator.handleCaptchaValidation(token: token, username: trimmedUsername)

        switch result {
        case .success:
            await loginSecurity.handleSuccessfulCaptcha(for: trimmedUsername)
            shouldShowCaptcha = false
            clearNotification()
            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

            await performAuthentication(
                username: trimmedUsername,
                password: trimmedPassword,
                isPostCaptchaRetry: true
            )
        case let .failure(error):
            captchaToken = nil
            showErrorNotification(title: "CAPTCHA Error", message: mapCaptchaError(error))
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
            "CAPTCHA service unavailable. Please try again later."
        case .rateLimitExceeded:
            "Too many CAPTCHA attempts. Please wait a moment and try again."
        case let .unknownError(message):
            "CAPTCHA error: \(message)"
        }
    }

    public func resetCaptchaState() {
        shouldShowCaptcha = false
        captchaToken = nil
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
        showSuccessNotification(title: "Login Successful", message: "Welcome! You have successfully logged in.")
        _errorMessage = nil
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
            clearNotification()
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
            let message = blockMessageProvider.message(
                for: LoginError.accountLocked(remainingTime: Int(remainingTime)))
            showErrorNotification(title: "Account Locked", message: message)
            isLoginBlocked = true
        } else {
            let errorMessage = mapLoginError(error, for: username)
            showErrorNotification(title: "Login Error", message: errorMessage)
        }

        updateViewState()
    }

    @MainActor
    private func checkAccountUnlock(for username: String) async {
        let isLocked = await loginSecurity.isAccountLocked(username: username)
        if isLocked {
            let remainingTime = loginSecurity.getRemainingBlockTime(username: username) ?? 0
            let message = blockMessageProvider.message(
                for: LoginError.accountLocked(remainingTime: Int(remainingTime)))
            showErrorNotification(title: "Account Locked", message: message)
            isLoginBlocked = true
            shouldShowCaptcha = true
        } else {
            isLoginBlocked = false
            clearNotification()
        }
    }

    public func handleRecoveryTap() {
        navigation?.showRecovery()
        recoveryRequested.send(())
    }

    public func handleRegisterTap() {
        navigation?.showRegister()
        registerRequested.send(())
    }

    public func userDidInitiateEditing() {
        if let notification = currentNotification, notification.type == .error {
            clearNotification()
        }
    }

    public var viewState: ViewState {
        if let notification = currentNotification {
            .showingNotification(notification)
        } else if isLoginBlocked {
            .blocked
        } else if let message = _errorMessage {
            .error(message)
        } else if loginSuccess {
            .success("Login successful!")
        } else {
            .idle
        }
    }

    private func updateViewState() {
        publishedViewState = viewState
    }

    deinit {
        delayTask?.cancel()
    }

    private func mapLoginError(_ error: LoginError, for _: String) -> String {
        switch error {
        case .invalidCredentials:
            "Invalid username or password."
        case .invalidEmailFormat:
            "Invalid username or password."
        case .invalidPasswordFormat:
            "Invalid username or password."
        case let .accountLocked(remainingTime):
            blockMessageProvider.message(for: LoginError.accountLocked(remainingTime: remainingTime))
        case .network:
            "A network error occurred. Please try again."
        case .tokenStorageFailed,
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
        clearNotification()
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
    }
}
