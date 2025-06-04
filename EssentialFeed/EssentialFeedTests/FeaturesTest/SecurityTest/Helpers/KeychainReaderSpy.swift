import EssentialFeed
import Foundation

final class KeychainReaderSpy: KeychainReader, @unchecked Sendable {
    enum Message: Equatable {
        case load(key: String)
    }

    private(set) var receivedMessages = [Message]()

    private var loadResult: Result<Data?, Error>?

    func load(forKey key: String) throws -> Data? {
        receivedMessages.append(.load(key: key))

        guard let loadResult else {
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
