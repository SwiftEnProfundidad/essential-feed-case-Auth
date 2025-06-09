import CryptoKit
@preconcurrency import EssentialFeed
import SwiftUI
import UIKit

public enum LoginComposer {
    @MainActor public static func composedLoginViewController(
        onAuthenticated: @escaping () -> Void,
        onRecoveryRequested: @escaping () -> Void
    ) -> UIViewController {
        let httpClient = URLSessionHTTPClient(session: URLSession(configuration: .ephemeral))

        let loginAPI = HTTPUserLoginAPI(client: httpClient)
        let loginFlowHandler = BasicLoginFlowHandler()
        loginFlowHandler.onAuthenticated = onAuthenticated

        let config = UserLoginConfiguration(
            maxFailedAttempts: 3,
            lockoutDuration: 300,
            tokenDuration: 3600
        )

        let keychainHelper = KeychainHelper()
        let keychainReader = KeychainHelperReaderAdapter(keychainHelper: keychainHelper)
        let keychainWriter = KeychainHelperWriterAdapter(keychainHelper: keychainHelper)

        let encryptor = SimpleEncryptor()
        let errorHandler = LoggingKeychainErrorHandler()

        let keychainManager = KeychainManager(
            reader: keychainReader,
            writer: keychainWriter,
            encryptor: encryptor,
            errorHandler: errorHandler
        )
        let tokenStorage = KeychainTokenStore(keychainManager: keychainManager)

        let offlineStore = InMemoryOfflineLoginStore()
        let loginPersistence = DefaultLoginPersistence(
            tokenStorage: tokenStorage,
            offlineStore: offlineStore,
            config: config
        )

        let validator = LoginCredentialsValidator()

        let failedLoginStore = InMemoryFailedLoginAttemptsStore()
        let securityUseCase = LoginSecurityUseCase(
            store: failedLoginStore,
            maxAttempts: config.maxFailedAttempts,
            blockDuration: config.lockoutDuration
        )

        let loginService = DefaultLoginService(
            validator: validator,
            securityUseCase: securityUseCase,
            api: loginAPI,
            persistence: loginPersistence,
            config: config
        )

        let userLoginUseCase = UserLoginUseCase(loginService: loginService)

        let viewModel = LoginViewModel(authenticate: { email, password in
            await userLoginUseCase.login(with: LoginCredentials(email: email, password: password))
        })

        return LoginUIComposer.composedLoginViewController(with: viewModel, onRecoveryRequested: onRecoveryRequested)
    }
}

// MARK: - Adapters to bridge KeychainHelper to KeychainReader/Writer

private final class KeychainHelperReaderAdapter: KeychainReader, @unchecked Sendable {
    private let keychainHelper: KeychainHelper

    init(keychainHelper: KeychainHelper) {
        self.keychainHelper = keychainHelper
    }

    func load(forKey key: String) throws -> Data? {
        keychainHelper.getData(key)
    }
}

private final class KeychainHelperWriterAdapter: KeychainWriter, @unchecked Sendable {
    private let keychainHelper: KeychainHelper

    init(keychainHelper: KeychainHelper) {
        self.keychainHelper = keychainHelper
    }

    func save(data: Data, forKey key: String) throws {
        let result = keychainHelper.save(data, for: key)
        switch result {
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }

    func delete(forKey key: String) throws {
        let result = keychainHelper.delete(key)
        switch result {
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }
}

// MARK: - Simple Encryptor (no-op for now)

private final class SimpleEncryptor: KeychainEncryptor, @unchecked Sendable {
    func encrypt(_ data: Data) throws -> Data {
        data // No encryption for now
    }

    func decrypt(_ data: Data) throws -> Data {
        data // No decryption for now
    }
}

// MARK: - Simple In-Memory Store for Demo

private final class InMemoryOfflineLoginStore: OfflineLoginStore, @unchecked Sendable {
    private var credentials: [LoginCredentials] = []

    func save(credentials: LoginCredentials) async throws {
        self.credentials.append(credentials)
    }

    func loadAll() async throws -> [LoginCredentials] {
        credentials
    }

    func delete(credentials: LoginCredentials) async throws {
        self.credentials.removeAll { $0.email == credentials.email }
    }
}

// MARK: - In Memory Failed Login Store for Demo

private final class InMemoryFailedLoginAttemptsStore: FailedLoginAttemptsStore, @unchecked Sendable {
    private var attempts: [String: Int] = [:]
    private var lastAttemptTimes: [String: Date] = [:]

    func getAttempts(for username: String) -> Int {
        attempts[username] ?? 0
    }

    func incrementAttempts(for username: String) async {
        attempts[username] = getAttempts(for: username) + 1
        lastAttemptTimes[username] = Date()
    }

    func resetAttempts(for username: String) async {
        attempts[username] = 0
        lastAttemptTimes[username] = nil
    }

    func lastAttemptTime(for username: String) -> Date? {
        lastAttemptTimes[username]
    }
}

// MARK: - Simple Error Handler

private final class LoggingKeychainErrorHandler: KeychainErrorHandling, @unchecked Sendable {
    func handle(error: KeychainError, forKey key: String?, operation: String) {
        print("Keychain error in \(operation) for key \(key ?? "unknown"): \(error)")
    }

    func handleUnexpectedError(forKey key: String?, operation: String) {
        print("Unexpected keychain error in \(operation) for key \(key ?? "unknown")")
    }
}
