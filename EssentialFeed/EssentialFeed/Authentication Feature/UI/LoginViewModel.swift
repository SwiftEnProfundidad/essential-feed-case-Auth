import Combine
import Foundation

// Importa el wrapper type-erased
// Asegúrate de que AnyLoginRequestStore.swift está en el mismo target
// y que LoginRequest.swift también está en el target

// No necesitas import explícito de archivo, solo asegúrate de que ambos están en el target

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

  /// Closure de autenticación asíncrona (production y tests)
  public var authenticate: (String, String) async -> Result<LoginResponse, LoginError>
  private let pendingRequestStore: AnyLoginRequestStore?
  private let failedAttemptsStore: FailedLoginAttemptsStore
  private let maxFailedAttempts: Int

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
  }

  @MainActor
  public func login() async {
    let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
    let attempts = failedAttemptsStore.getAttempts(for: trimmedUsername)

    if attempts >= maxFailedAttempts {
      isLoginBlocked = true
      let delay = calculateDelay(attempts: attempts)
      errorMessage = "Too many attempts. Please try again in \(Int(delay)) seconds or reset your password."
      
      // Mantener el estado durante el delay
      let startTime = Date()
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      
      // Solo limpiar si el delay completo ha terminado
      if Date().timeIntervalSince(startTime) >= delay {
        isLoginBlocked = false
        errorMessage = nil
      }
      return
    }

    do {
      let result = await authenticate(trimmedUsername, password)
      failedAttemptsStore.resetAttempts(for: trimmedUsername)

      switch result {
      case .success:
        errorMessage = nil
        loginSuccess = true
        authenticated.send(())
      case .failure(let error):
        failedAttemptsStore.incrementAttempts(for: trimmedUsername)
        errorMessage = LoginErrorMessageMapper.message(for: error)
        loginSuccess = false

        if case .network = error {
          let request = LoginRequest(username: trimmedUsername, password: password)
          pendingRequestStore?.save(request)
        }
      }
    }
  }

  private func calculateDelay(attempts: Int) -> TimeInterval {
    let baseDelay = 1.0  // 1 segundo base para testing
    return min(baseDelay * pow(2, Double(attempts - maxFailedAttempts)), 5.0)  // Máximo 5 segundos para testing
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
}
