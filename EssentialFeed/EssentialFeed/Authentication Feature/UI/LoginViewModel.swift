import Combine
import Foundation

public protocol LoginNavigation: AnyObject {
  func showRecovery()
}

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
  @Published public var isLoginBlocked = false
  public let authenticated = PassthroughSubject<Void, Never>()
  public let recoveryRequested = PassthroughSubject<Void, Never>()
  private var cancellables: Set<AnyCancellable> = []
  private var delayTask: Task<Void, Never>?

  /// Closure de autenticación asíncrona (production y tests)
  public var authenticate: (String, String) async -> Result<LoginResponse, LoginError>
  private let pendingRequestStore: AnyLoginRequestStore?
  private let failedAttemptsStore: FailedLoginAttemptsStore
  private let maxFailedAttempts: Int
  private let blockMessageProvider: LoginBlockMessageProvider
  private let timeProvider: () -> Date
  public weak var navigation: LoginNavigation?

  public init(
    authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>,
    pendingRequestStore: AnyLoginRequestStore? = nil,
    failedAttemptsStore: FailedLoginAttemptsStore = InMemoryFailedLoginAttemptsStore(),
    maxFailedAttempts: Int = 5,
    blockMessageProvider: LoginBlockMessageProvider = DefaultLoginBlockMessageProvider(),
    timeProvider: @escaping () -> Date = { Date() }
  ) {
    self.authenticate = authenticate
    self.pendingRequestStore = pendingRequestStore
    self.failedAttemptsStore = failedAttemptsStore
    self.maxFailedAttempts = maxFailedAttempts
    self.blockMessageProvider = blockMessageProvider
    self.timeProvider = timeProvider
    recoveryRequested
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.navigation?.showRecovery()
      }
      .store(in: &cancellables)
  }

  @MainActor
  public func login() async {
    print("➡️ [LoginViewModel] login() called for username: \(username)")
    checkAccountUnlock(for: username)
    print("  [LoginViewModel] After checkAccountUnlock: isLoginBlocked=\(isLoginBlocked), errorMessage=\(String(describing: errorMessage))")
    guard !isAccountLocked(for: username) else {
        isLoginBlocked = true
        errorMessage = blockMessageProvider.messageForMaxAttemptsReached()
        return
    }
    
    delayTask?.cancel()

    let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmedUsername.isEmpty {
      errorMessage = blockMessageProvider.message(for: .emptyEmail)
      return
    }

    if trimmedPassword.isEmpty {
      errorMessage = blockMessageProvider.message(for: .emptyPassword)
      return
    }

    let result = await authenticate(trimmedUsername, trimmedPassword)

    switch result {
			case .success(_):
      await MainActor.run {
        loginSuccess = true
        authenticated.send(())
        errorMessage = nil
        isLoginBlocked = false
        failedAttemptsStore.resetAttempts(for: trimmedUsername)
      }
      onAuthenticated?()
    case .failure(let error):
      await handleFailedLogin(username: trimmedUsername)
      if case .network = error {
        let request = LoginRequest(username: trimmedUsername, password: trimmedPassword)
        pendingRequestStore?.save(request)
      }
    }
  }

  // Desbloquear tras recuperación
  public func unlockAfterRecovery() {
    isLoginBlocked = false
    errorMessage = nil
  }

  private func calculateDelay(attempts: Int) -> TimeInterval {
    let baseDelay = 0.5
    let additionalDelay = Double(attempts - maxFailedAttempts) * 0.5
    return max(baseDelay, baseDelay + additionalDelay)
  }

  private func isAccountLocked(for username: String) -> Bool {
    let attempts = failedAttemptsStore.getAttempts(for: username)
    guard attempts >= maxFailedAttempts else { return false }
    guard let lastAttempt = failedAttemptsStore.lastAttemptTime(for: username) else { return false }
    let elapsed = timeProvider().timeIntervalSince(lastAttempt)
    return elapsed < 5 * 60 // bloqueado si no ha pasado el timeout
  }

  private func handleFailedLogin(username: String) async {
    failedAttemptsStore.incrementAttempts(for: username)
    let attempts = failedAttemptsStore.getAttempts(for: username)
    
    await MainActor.run { [weak self] in
        guard let self = self else { return }
        
        // Mostrar error en todos los intentos fallidos
        if attempts < self.maxFailedAttempts {
            self.errorMessage = "Invalid credentials"
        } else {
            self.errorMessage = self.blockMessageProvider.messageForMaxAttemptsReached()
            self.isLoginBlocked = true
        }
    }
    
    // Aplicar delay de seguridad
    if attempts >= maxFailedAttempts {
        let delay = calculateDelay(attempts: attempts)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
  }

  private func checkAccountUnlock(for username: String) {
    let attempts = failedAttemptsStore.getAttempts(for: username)
    print("  [LoginViewModel] checkAccountUnlock: attempts=\(attempts), maxFailedAttempts=\(maxFailedAttempts)")
    guard attempts >= maxFailedAttempts else { return }
    guard let lastAttempt = failedAttemptsStore.lastAttemptTime(for: username) else { return }
    let elapsed = timeProvider().timeIntervalSince(lastAttempt)
    print("  [LoginViewModel] checkAccountUnlock: elapsed since lastAttempt=\(elapsed)")
    if elapsed >= 5 * 60 {
        print("  [LoginViewModel] Account unlocked and attempts reset for \(username)")
        failedAttemptsStore.resetAttempts(for: username)
        isLoginBlocked = false
        errorMessage = nil
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

  deinit {
    delayTask?.cancel()
  }
}
