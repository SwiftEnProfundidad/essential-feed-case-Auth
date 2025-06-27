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
                Task { @MainActor in
                    userDidInitiateEditing()
                }
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
            if captchaToken != nil, !isCaptchaValidating {
                Task {
                    await handleCaptchaFlow()
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
    private let loginSecurity: LoginSecurityUseCase
    private let blockMessageProvider: LoginBlockMessageProvider
    public var navigation: LoginNavigation?
    public var captchaFlowCoordinator: CaptchaFlowCoordinating?
    public var pendingRequestStore: Any?

    private var isCaptchaValidating = false
    private var isCurrentlyAuthenticating = false
    private var currentLoginTask: Task<Void, Never>?

    public init(
        authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>,
        loginSecurity: LoginSecurityUseCase = LoginSecurityUseCase(),
        blockMessageProvider: LoginBlockMessageProvider = DefaultLoginBlockMessageProvider(),
        captchaFlowCoordinator: CaptchaFlowCoordinating? = nil
    ) {
        self.authenticate = authenticate
        self.loginSecurity = loginSecurity
        self.blockMessageProvider = blockMessageProvider
        self.captchaFlowCoordinator = captchaFlowCoordinator
        self.pendingRequestStore = nil
    }

    @MainActor
    public func login() async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        forceResetAllStates()

        guard !isCaptchaValidating else {
            print(" Login blocked: CAPTCHA validation in progress")
            return
        }

        guard !trimmedUsername.isEmpty, !trimmedPassword.isEmpty else {
            showErrorNotification(
                title: NSLocalizedString("LOGIN_ALERT_ERROR_TITLE", comment: "Error alert title"),
                message: NSLocalizedString("LOGIN_ERROR_VALIDATION", comment: "Validation error message")
            )
            return
        }

        if await loginSecurity.isAccountLocked(username: trimmedUsername) {
            let remainingTime = loginSecurity.getRemainingBlockTime(username: trimmedUsername) ?? 0
            let message = blockMessageProvider.message(
                for: LoginError.accountLocked(remainingTime: Int(remainingTime)))
            showErrorNotification(
                title: NSLocalizedString("LOGIN_ALERT_ERROR_TITLE", comment: "Error alert title"),
                message: message
            )
            isLoginBlocked = true
            shouldShowCaptcha = false
            return
        } else {
            isLoginBlocked = false
        }

        if shouldShowCaptcha, captchaToken == nil {
            showErrorNotification(
                title: NSLocalizedString("CAPTCHA_REQUIRED_TITLE", comment: "CAPTCHA required title"),
                message: NSLocalizedString("CAPTCHA_REQUIRED_MESSAGE", comment: "CAPTCHA required message")
            )
            return
        }

        await performAuthentication(username: trimmedUsername, password: trimmedPassword)
    }

    private func showSuccessNotification(title: String, message: String) {
        guard !isCaptchaValidating else { return }

        currentNotification = InAppNotification(
            title: title,
            message: message,
            type: .success,
            actionButton: "Continue"
        )
    }

    private func showErrorNotification(title: String, message: String) {
        guard !isCaptchaValidating else { return }

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

    @MainActor
    public func dismissNotification() {
        forceResetAllStates()
    }

    public func resetCaptchaState() {
        shouldShowCaptcha = false
        captchaToken = nil
        Task { @MainActor in
            forceResetAllStates()
        }
    }

    @MainActor
    public func handleRecoveryTap() {
        navigation?.showRecovery()
        recoveryRequested.send()
    }

    @MainActor
    public func handleRegisterTap() {
        navigation?.showRegister()
        registerRequested.send()
    }

    @MainActor
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

        if case .showingNotification = viewState {
            isPerformingLogin = false
        }
        if isLoginBlocked {
            isPerformingLogin = false
        }
    }

    @MainActor
    private func handleCaptchaFlow() async {
        await validateCaptchaAndProceed()
    }

    @MainActor
    private func validateCaptchaAndProceed() async {
        guard let coordinator = captchaFlowCoordinator else { return }
        guard let token = captchaToken else { return }
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !isCaptchaValidating else {
            print(" CAPTCHA validation already in progress, skipping")
            return
        }

        print(" Validating CAPTCHA for user: \(trimmedUsername)")

        currentLoginTask?.cancel()
        currentLoginTask = nil

        isCaptchaValidating = true
        isPerformingLogin = true

        currentNotification = nil
        _errorMessage = nil

        let result = await coordinator.handleCaptchaValidation(token: token, username: trimmedUsername)

        await MainActor.run {
            isCaptchaValidating = false
            isPerformingLogin = false

            switch result {
            case .success:
                print(" CAPTCHA validation successful")

                Task {
                    await loginSecurity.handleSuccessfulCaptcha(for: trimmedUsername)
                    await loginSecurity.resetAttempts(username: trimmedUsername)

                    await MainActor.run {
                        shouldShowCaptcha = false
                        isLoginBlocked = false
                        clearNotification()

                        currentNotification = InAppNotification(
                            title: NSLocalizedString("CAPTCHA_VERIFIED_TITLE", comment: "CAPTCHA verified title"),
                            message: NSLocalizedString("CAPTCHA_VERIFIED_MESSAGE", comment: "CAPTCHA verified message"),
                            type: .success,
                            actionButton: "Continue"
                        )
                    }
                }

            case let .failure(error):
                print(" CAPTCHA validation failed: \(error)")
                captchaToken = nil
                currentNotification = InAppNotification(
                    title: NSLocalizedString("CAPTCHA_ERROR_TITLE", comment: "CAPTCHA error title"),
                    message: mapCaptchaError(error),
                    type: .error,
                    actionButton: "OK"
                )
            }
        }
    }

    @MainActor
    private func performAuthentication(
        username: String, password: String, isPostCaptchaRetry: Bool = false
    ) async {
        print(" Performing authentication for: \(username), isPostCaptchaRetry: \(isPostCaptchaRetry)")

        currentLoginTask = Task {
            isPerformingLogin = true
            let authResult = await authenticate(username, password)

            guard !Task.isCancelled else {
                print(" Authentication task was cancelled")
                isPerformingLogin = false
                return
            }

            switch authResult {
            case .success:
                print(" Authentication successful")
                await handleSuccessfulLogin(username: username)
            case let .failure(error):
                print(" Authentication failed: \(error)")
                await handleFailedLogin(error, for: username, isPostCaptchaRetry: isPostCaptchaRetry)
            }
        }

        await currentLoginTask?.value
    }

    @MainActor
    private func handleSuccessfulLogin(username: String) async {
        await loginSecurity.resetAttempts(username: username)
        loginSuccess = true
        authenticated.send()

        showSuccessNotification(
            title: NSLocalizedString("LOGIN_ALERT_SUCCESS_TITLE", comment: "Success alert title"),
            message: NSLocalizedString("LOGIN_ALERT_SUCCESS_MESSAGE", comment: "Login successful message")
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.onAuthenticated?()
        }

        _errorMessage = nil
        isLoginBlocked = false
        isPerformingLogin = false
        resetCaptchaState()
    }

    @MainActor
    private func handleFailedLogin(_ error: LoginError, for username: String, isPostCaptchaRetry: Bool = false) async {
        print(" Handling failed login for: \(username), isPostCaptchaRetry: \(isPostCaptchaRetry)")

        forceResetAllStates()

        if isPostCaptchaRetry {
            print(" Post-CAPTCHA retry failed")
            let errorMessage = mapLoginError(error, for: username)
            showErrorNotification(
                title: NSLocalizedString("LOGIN_ALERT_ERROR_TITLE", comment: "Error alert title"),
                message: errorMessage
            )
            resetCaptchaState()
            return
        }

        switch error {
        case .accountLocked:
            let message = blockMessageProvider.message(for: error)
            showErrorNotification(
                title: NSLocalizedString("LOGIN_ALERT_ERROR_TITLE", comment: "Error alert title"),
                message: message
            )
            isLoginBlocked = true
            shouldShowCaptcha = false

        case .invalidCredentials:
            await loginSecurity.handleFailedLogin(username: username)

            let attempts = loginSecurity.getFailedAttempts(username: username)
            print(" Total failed attempts: \(attempts)")

            let isNowLocked = await loginSecurity.isAccountLocked(username: username)

            if isNowLocked {
                let remainingTime = loginSecurity.getRemainingBlockTime(username: username) ?? 0
                let message = blockMessageProvider.message(
                    for: LoginError.accountLocked(remainingTime: Int(remainingTime)))
                showErrorNotification(title: NSLocalizedString("LOGIN_ALERT_ERROR_TITLE", comment: "Error alert title"), message: message)
                isLoginBlocked = true
                shouldShowCaptcha = false
            } else {
                if let coordinator = captchaFlowCoordinator {
                    shouldShowCaptcha = coordinator.shouldTriggerCaptcha(failedAttempts: attempts)
                    print(" shouldShowCaptcha: \(shouldShowCaptcha)")
                }

                if !shouldShowCaptcha {
                    let errorMessage = mapLoginError(error, for: username)
                    showErrorNotification(
                        title: NSLocalizedString("LOGIN_ALERT_ERROR_TITLE", comment: "Error alert title"),
                        message: errorMessage
                    )
                }
            }

        default:
            let errorMessage = mapLoginError(error, for: username)
            showErrorNotification(
                title: NSLocalizedString("LOGIN_ALERT_ERROR_TITLE", comment: "Error alert title"),
                message: errorMessage
            )
        }
    }

    private func mapLoginError(_ error: LoginError, for _: String) -> String {
        switch error {
        case .invalidCredentials:
            NSLocalizedString("LOGIN_ERROR_INVALID_CREDENTIALS", comment: "Invalid credentials error")
        case .invalidEmailFormat:
            NSLocalizedString("LOGIN_ERROR_INVALID_CREDENTIALS", comment: "Invalid credentials error")
        case .invalidPasswordFormat:
            NSLocalizedString("LOGIN_ERROR_INVALID_CREDENTIALS", comment: "Invalid credentials error")
        case let .accountLocked(remainingTime):
            blockMessageProvider.message(for: LoginError.accountLocked(remainingTime: remainingTime))
        case .network:
            NSLocalizedString("LOGIN_ERROR_NETWORK", comment: "Network error")
        case .tokenStorageFailed,
             .noConnectivity,
             .offlineStoreFailed,
             .messageForMaxAttemptsReached,
             .unknown:
            error.errorMessage()
        }
    }

    private func mapCaptchaError(_ error: Error) -> String {
        if let captchaError = error as? CaptchaError {
            switch captchaError {
            case .invalidResponse:
                return NSLocalizedString("CAPTCHA_ERROR_INVALID_RESPONSE", comment: "CAPTCHA verification failed")
            case .networkError:
                return NSLocalizedString("CAPTCHA_ERROR_NETWORK", comment: "Network error during CAPTCHA verification")
            case .malformedRequest:
                return NSLocalizedString("CAPTCHA_ERROR_MALFORMED_REQUEST", comment: "CAPTCHA request error")
            case .serviceUnavailable:
                return NSLocalizedString("CAPTCHA_ERROR_SERVICE_UNAVAILABLE", comment: "CAPTCHA service unavailable")
            case .rateLimitExceeded:
                return NSLocalizedString("CAPTCHA_ERROR_RATE_LIMIT", comment: "Too many CAPTCHA attempts")
            case let .unknownError(message):
                return String(format: NSLocalizedString("CAPTCHA_ERROR_UNKNOWN_FORMAT", comment: "Unknown CAPTCHA error"), message)
            }
        }

        return NSLocalizedString("CAPTCHA_ERROR_GENERIC", comment: "Generic CAPTCHA error")
    }

    @MainActor
    private func forceResetAllStates() {
        print(" FORCE RESET: Stopping all operations and clearing state")

        currentLoginTask?.cancel()
        currentLoginTask = nil

        isPerformingLogin = false
        isCaptchaValidating = false

        currentNotification = nil
        _errorMessage = nil

        updateViewState()
    }

    deinit {
        delayTask?.cancel()
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
