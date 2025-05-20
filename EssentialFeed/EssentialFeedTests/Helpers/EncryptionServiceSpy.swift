import Foundation

public final class EncryptionServiceSpy {
    public enum Message: Equatable {
        case encrypt(Data)
    }

    public private(set) var messages = [Message]()

    public var receivedDataForEncryption: Data? {
        if case let .encrypt(data) = messages.first {
            return data
        }
        return nil
    }

    public var encryptedDataCallCount: Int {
        messages.filter { if case .encrypt = $0 { true } else { false } }.count
    }

    public var encryptionShouldSucceed: Bool = true
    public var encryptedStringStub: String = "encrypted-token"

    public init() {}

    public func encrypt(_ data: Data) throws -> String {
        messages.append(.encrypt(data))
        if encryptionShouldSucceed {
            return encryptedStringStub
        } else {
            throw NSError(domain: "EncryptionServiceSpy", code: 0, userInfo: [NSLocalizedDescriptionKey: "Simulated encryption error"])
        }
    }
}
