import CryptoKit
@preconcurrency import EssentialFeed
import Foundation

public enum KeychainDependencyFactory {
    public static func makeKeychainManager() -> KeychainManager {
        let keychainHelper = KeychainHelper()
        let readerAdapter = KeychainHelperReaderAdapter(keychainHelper: keychainHelper)
        let writerAdapter = KeychainHelperWriterAdapter(keychainHelper: keychainHelper)
        let symmetricKey = SymmetricKey(size: .bits256)
        let aesEncryptor = AES256CryptoKitEncryptor(symmetricKey: symmetricKey)
        // This will now correctly refer to EssentialFeed.LoggingKeychainErrorHandler
        // which implements EssentialFeed.KeychainErrorHandler
        let loggingErrorHandler: KeychainErrorHandler = LoggingKeychainErrorHandler()

        return KeychainManager(
            reader: readerAdapter,
            writer: writerAdapter,
            encryptor: aesEncryptor,
            errorHandler: loggingErrorHandler
        )
    }

    public static func makeTokenStorage() -> TokenStorage {
        let manager = makeKeychainManager()
        return KeychainTokenStore(keychainManager: manager)
    }
}
