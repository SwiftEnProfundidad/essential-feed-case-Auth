import CryptoKit
import Foundation

public enum CryptoKitEncryptionError: LocalizedError {
    case encryptionFailed(Error?)
    case decryptionFailed(Error?)
    case invalidSealedBoxData
    case keyIsNil

    public var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            "Data encryption failed."
        case .decryptionFailed:
            "Data decryption failed."
        case .invalidSealedBoxData:
            "Sealed box data is invalid or malformed."
        case .keyIsNil:
            "Key is nil."
        }
    }
}

public final class AES256CryptoKitEncryptor: KeychainEncryptor {
    private let symmetricKey: SymmetricKey

    public init(symmetricKey: SymmetricKey) {
        self.symmetricKey = symmetricKey
    }

    public func encrypt(_ data: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            guard let combinedData = sealedBox.combined else {
                throw CryptoKitEncryptionError.encryptionFailed(nil)
            }
            return combinedData
        } catch {
            throw CryptoKitEncryptionError.encryptionFailed(error)
        }
    }

    public func decrypt(_ data: Data) throws -> Data {
        // self.symmetricKey is non-optional as it's set during successful initialization.
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: self.symmetricKey)
            return decryptedData
        } catch let cryptoKitError as CryptoKit.CryptoKitError {
            if case .incorrectParameterSize = cryptoKitError {
                throw CryptoKitEncryptionError.invalidSealedBoxData
            }
            throw CryptoKitEncryptionError.decryptionFailed(cryptoKitError)
        } catch {
            throw CryptoKitEncryptionError.decryptionFailed(error)
        }
    }
}
