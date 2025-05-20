import EssentialFeed
import Foundation

final class KeychainReaderSpy: KeychainReader {
    enum Message: Equatable {
        case load(key: String)
    }

    private(set) var receivedMessages = [Message]()

    private var loadResult: Result<Data?, Error>?

    func load(forKey key: String) throws -> Data? {
        receivedMessages.append(.load(key: key))

        guard let loadResult else {
            // Default behavior or throw a "not stubbed" error if you prefer
            return nil
        }

        switch loadResult {
        case let .success(data):
            return data
        case let .failure(error):
            throw error
        }
    }

    func completeLoad(with data: Data?) {
        loadResult = .success(data)
    }

    func completeLoad(with error: Error) {
        loadResult = .failure(error)
    }
}
