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
  public weak var navigation: LoginNavigation?

  public init(
    authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>,
    pendingRequestStore: AnyLoginRequestStore? = nil,
    failedAttemptsStore: FailedLoginAttemptsStore = InMemoryFailedLoginAttemptsStore(),
    maxFailedAttempts: Int = 5
  ) {
    self.authenticate = authenticate
    self.pendingRequestStore = pendingRequestStore
    self.failedAttemptsStore = failedAttemptsStore
    self.maxFailedAttempts = maxFailedAttempts
    recoveryRequested
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.navigation?.showRecovery()
        }
        .store(in: &cancellables)
  }

  @MainActor
  public func login() async {
    delayTask?.cancel()

    let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Validaciones
    guard !trimmedUsername.isEmpty else {
        errorMessage = "Email format is invalid."
        return
    }
    
    guard !trimmedPassword.isEmpty else {
        errorMessage = "Password cannot be empty."
        return
    }

    let result = await authenticate(trimmedUsername, trimmedPassword)

    switch result {
    case .success:
      failedAttemptsStore.resetAttempts(for: trimmedUsername)
      errorMessage = nil
      loginSuccess = true
      isLoginBlocked = false // desbloquea en login exitoso
      authenticated.send(())
    case .failure(let error):
      failedAttemptsStore.incrementAttempts(for: trimmedUsername)
      let afterAttempts = failedAttemptsStore.getAttempts(for: trimmedUsername)
      if afterAttempts >= maxFailedAttempts {
        await MainActor.run {
          isLoginBlocked = true
          errorMessage = "Too many attempts. Please wait 5 minutes or reset your password."
        }
        let delay = max(0.5, Double(afterAttempts - maxFailedAttempts + 1) * 0.5)
        do {
          try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } catch {
          // Si la tarea se cancela, mantener el bloqueo
        }
      } else {
        errorMessage = LoginErrorMessageMapper.message(for: error)
      }
      loginSuccess = false
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
    return attempts >= maxFailedAttempts
  }

  private func handleFailedLogin(username: String) async {
    failedAttemptsStore.incrementAttempts(for: username)
    let attempts = failedAttemptsStore.getAttempts(for: username)

    if attempts >= maxFailedAttempts {
      let delay = calculateDelay(attempts: attempts)
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
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

  private func localizedErrorMessage() -> String {
    return "Too many attempts. Please wait 5 minutes or reset your password."
  }

  deinit {
    delayTask?.cancel()
  }
}
