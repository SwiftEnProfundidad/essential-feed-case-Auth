import Foundation

public final class KeychainTokenStore: TokenStorage {
    private let keychainManager: KeychainManager
    private let tokenKeychainKey: String

    public init(
        keychainManager: KeychainManager, tokenKeychainKey: String = "com.essentialfeed.authTokenBundle"
    ) {
        self.keychainManager = keychainManager
        self.tokenKeychainKey = tokenKeychainKey
    }

    public func save(tokenBundle: Token) async throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let tokenData = try encoder.encode(tokenBundle)
            try keychainManager.save(data: tokenData, forKey: tokenKeychainKey)
        } catch let error as KeychainError {
            throw error
        } catch let encodingError {
            throw TokenStorageError.encodingFailed(encodingError)
        }
    }

    public func loadTokenBundle() async throws -> Token? {
        do {
            guard let tokenData = try keychainManager.load(forKey: tokenKeychainKey) else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let tokenBundle = try decoder.decode(Token.self, from: tokenData)
            return tokenBundle
        } catch let error as KeychainError {
            if case .itemNotFound = error {
                return nil
            }
            throw error
        } catch let decodingError {
            throw TokenStorageError.decodingFailed(decodingError)
        }
    }

    public func deleteTokenBundle() async throws {
        do {
            try keychainManager.delete(forKey: tokenKeychainKey)
        } catch let error as KeychainError {
            if case .itemNotFound = error {
                return
            }
            throw error
        } catch {
            throw error
        }
    }
}
