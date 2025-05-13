import Foundation

public enum SecureStorageProtectionLevel {
    case high
    case medium
    case low
}

public protocol SecureStoreWriter {
    func save(_ data: Data, forKey key: String) throws
}

public protocol SecureStoreReader {
    func retrieve(forKey key: String) throws -> Data
}

public protocol SecureStoreDeleter {
    func delete(forKey key: String) throws
}

public protocol EncryptionService {
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}

public typealias SecureStore = SecureStoreDeleter & SecureStoreReader & SecureStoreWriter

public final class SecureStorage {
    private let store: SecureStore
    private let encryptionService: EncryptionService

    public init(store: SecureStore, encryptionService: EncryptionService) {
        self.store = store
        self.encryptionService = encryptionService
    }

    public func protectionLevel(for data: Data) -> SecureStorageProtectionLevel {
        guard let content = String(data: data, encoding: .utf8) else {
            return .high
        }

        let lowercaseContent = content.lowercased()

        let sensitiveKeywords = ["password", "token", "key", "secret", "auth", "credentials"]
        if sensitiveKeywords.contains(where: { lowercaseContent.contains($0) }) {
            return .high
        }

        let personalKeywords = ["name", "email", "phone", "address", "birth"]
        if personalKeywords.contains(where: { lowercaseContent.contains($0) }) {
            return .medium
        }

        let words = content.split(separator: " ")
        let capitalizedWords = words.filter { word in
            guard let firstChar = word.first else { return false }
            return String(firstChar).uppercased() == String(firstChar)
        }

        if capitalizedWords.count >= 2 {
            return .medium
        }

        return .low
    }

    public func save(_ data: Data, forKey key: String) throws {
        let level = protectionLevel(for: data)
        switch level {
        case .high, .medium:
            let encryptedData = try encryptionService.encrypt(data)
            try store.save(encryptedData, forKey: key)
        case .low:
            try store.save(data, forKey: key)
        }
    }
}
