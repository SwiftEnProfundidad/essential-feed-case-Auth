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

    @Published private(set) var isPerformingLogin: Bool = false

    @Published public private(set) var publishedViewState: ViewState = .idle
    @Published public var shouldShowCaptcha: Bool = false {
        didSet { updateViewState() }
    }

    @Published public var captchaToken: String? = nil {
        didSet {
            let currentTokenDisplay = captchaToken == nil ? "nil" : "TOKEN"
            let oldValueDisplay = oldValue == nil ? "nil" : "TOKEN"
            print(
                "LoginViewModel: captchaToken.didSet - Current: \(currentTokenDisplay), Old: \(oldValueDisplay), shouldShowCaptcha: \(shouldShowCaptcha)"
            )

            let shouldLaunchValidation =
                captchaToken != nil && (oldValue == nil || oldValue != captchaToken)

            if shouldLaunchValidation {
                print(
                    "LoginViewModel: captchaToken.didSet - LAUNCHING validateCaptchaAndProceed() because token is new (was nil) or changed from previous value."
                )
                Task { await validateCaptchaAndProceed() }
            } else {
                print(
                    "LoginViewModel: captchaToken.didSet - NOT launching validateCaptchaAndProceed(). Token is nil, or is the same as previous non-nil value."
                )
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
        let callID = String(UUID().uuidString.prefix(4))
        print(
            "LoginViewModel: validateCaptchaAndProceed [\(callID)] - ENTERED. Current token: \(captchaToken == nil ? "nil" : "TOKEN")"
        )

        guard let (trimmedUsernameForCaptcha, _) = validateCredentials() else {
            print(
                "LoginViewModel: validateCaptchaAndProceed [\(callID)] - GUARD FAILED (invalid credentials). Cannot proceed with CAPTCHA validation."
            )
            return
        }

        guard let token = captchaToken,
              let coordinator = captchaFlowCoordinator
        else {
            print(
                "LoginViewModel: validateCaptchaAndProceed [\(callID)] - GUARD FAILED (token or coordinator nil). Current token: \(captchaToken == nil ? "nil" : "TOKEN")"
            )
            return
        }

        print(
            "LoginViewModel: validateCaptchaAndProceed [\(callID)] - Calling coordinator.handleCaptchaValidation with token: \(token.prefix(10))..., username: \(trimmedUsernameForCaptcha)"
        )
        let result = await coordinator.handleCaptchaValidation(
            token: token, username: trimmedUsernameForCaptcha
        )

        switch result {
        case .success:
            print(
                "LoginViewModel: validateCaptchaAndProceed [\(callID)] - Captcha validation SUCCESSFUL.")
            shouldShowCaptcha = false
            captchaToken = nil
            errorMessage = nil

            await loginSecurity.resetAttempts(username: trimmedUsernameForCaptcha)
            print(
                "LoginViewModel: validateCaptchaAndProceed [\(callID)] - Reset login attempts after successful CAPTCHA validation."
            )

            await performAuthentication(
                username: trimmedUsernameForCaptcha,
                password: self.password.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        case let .failure(error):
            print(
                "LoginViewModel: validateCaptchaAndProceed [\(callID)] - Captcha validation FAILED: \(error). Setting captchaToken to nil."
            )
            captchaToken = nil
            errorMessage = mapCaptchaError(error)
        }
        print("LoginViewModel: validateCaptchaAndProceed [\(callID)] - EXITED.")
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
        isPerformingLogin = true
        errorMessage = nil

        let result = await self.authenticate(username, password)
        isPerformingLogin = false

        if case let .failure(error) = result {
            print("LoginViewModel - performAuthentication - Received error: \(error)")
        }

        switch result {
        case .success:
            await handleSuccessfulLogin(username: username)
        case let .failure(error):
            await handleFailedLogin(error, for: username)
            if case .network = error {
                savePendingRequest(username: username, password: password)
            }
        }
    }

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
    private func handleFailedLogin(_ error: LoginError, for username: String) async {
        isPerformingLogin = false
        await loginSecurity.handleFailedLogin(username: username)
        let failedAttempts = loginSecurity.getFailedAttempts(username: username)

        if let coordinator = captchaFlowCoordinator,
           coordinator.shouldTriggerCaptcha(failedAttempts: failedAttempts)
        {
            print("LoginViewModel: CAPTCHA should be triggered. Attempts: \(failedAttempts)")
            shouldShowCaptcha = true
            errorMessage = "Please complete the CAPTCHA verification"
        } else if await loginSecurity.isAccountLocked(username: username) {
            let remainingTime = loginSecurity.getRemainingBlockTime(username: username) ?? 0
            errorMessage = blockMessageProvider.message(
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
                if case let .failure(error) = authResult {
                    print(
                        "LoginViewModel - retryPendingRequests - Received error from authenticate for \(req.username): \(error)"
                    )
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

extension LoginViewModel: LoginViewModelProtocol {}

extension LoginViewModel: CaptchaStateManaging {
    public func setCaptchaRequired(_ required: Bool) {
        shouldShowCaptcha = required
    }

    public func setCaptchaToken(_ token: String?) {
        print("LoginViewModel: setCaptchaToken CALLED with \(token == nil ? "nil" : "TOKEN")")
        self.captchaToken = token
    }

    public func resetCaptchaState() {
        shouldShowCaptcha = false
        captchaToken = nil
    }
}
