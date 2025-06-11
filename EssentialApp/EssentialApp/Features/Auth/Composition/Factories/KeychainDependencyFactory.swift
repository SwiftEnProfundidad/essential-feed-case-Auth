import CryptoKit
@preconcurrency import EssentialFeed
import Foundation

enum KeychainDependencyFactory {
    static func makeKeychainManager() -> KeychainManager {
        let keychainHelper = KeychainHelper()
        let keychainReader = KeychainHelperReaderAdapter(keychainHelper: keychainHelper)
        let keychainWriter = KeychainHelperWriterAdapter(keychainHelper: keychainHelper)
        let encryptor = SimpleEncryptor()
        let errorHandler = LoggingKeychainErrorHandler()

        return KeychainManager(
            reader: keychainReader,
            writer: keychainWriter,
            encryptor: encryptor,
            errorHandler: errorHandler
        )
    }

    static func makeTokenStorage() -> TokenStorage {
        let keychainManager = makeKeychainManager()
        return KeychainTokenStore(keychainManager: keychainManager)
    }
}
