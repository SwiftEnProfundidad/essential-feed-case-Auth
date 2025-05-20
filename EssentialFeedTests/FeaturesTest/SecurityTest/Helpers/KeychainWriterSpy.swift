import EssentialFeed
import Foundation

final class KeychainWriterSpy: KeychainWriter {
    enum Message: Equatable {
        case save(data: Data, key: String)
        case delete(key: String)
    }

    private(set) var receivedMessages = [Message]()

    private var saveError: Error?
    private var deleteError: Error?

    // Save
    func save(data: Data, forKey key: String) throws {
        receivedMessages.append(.save(data: data, key: key))
        if let saveError {
            throw saveError
        }
    }

    func completeSave(with error: Error) {
        saveError = error
    }

    func completeSaveSuccessfully() {
        saveError = nil
    }

    // Delete
    func delete(forKey key: String) throws {
        receivedMessages.append(.delete(key: key))
        if let deleteError {
            throw deleteError
        }
    }

    func completeDelete(with error: Error) {
        deleteError = error
    }

    func completeDeleteSuccessfully() {
        deleteError = nil
    }
}
