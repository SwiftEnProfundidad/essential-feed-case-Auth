import Foundation
import Combine

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
		let attempts = failedAttemptsStore.getAttempts(for: trimmedUsername)
		
		if attempts >= maxFailedAttempts {
			isLoginBlocked = true
			errorMessage = "Demasiados intentos. Por favor, espera 5 minutos o recupera tu contraseña."
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
					errorMessage = LoginErrorMessageMapper.message(for: error)
					loginSuccess = false
					if case .network = error {
						let request = LoginRequest(username: trimmedUsername, password: password)
						pendingRequestStore?.save(request)
					}
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
}
