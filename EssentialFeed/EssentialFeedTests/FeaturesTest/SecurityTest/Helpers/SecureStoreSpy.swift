
import EssentialFeed
import Foundation

final class SecureStoreSpy: SecureStore {
    enum ReceivedMessage: Equatable {
        case save(key: String, value: Data)
        case retrieve(key: String)
        case delete(key: String)
    }

    private(set) var receivedMessages: [ReceivedMessage] = .init()
    private var stubbedSaveResults: [String: Result<Void, Error>] = .init()
    private var stubbedRetrievalResults: [String: Result<Data, Error>] = .init()
    private var stubbedDeleteResults: [String: Result<Void, Error>] = .init()

    func save(_ data: Data, forKey key: String) throws {
        receivedMessages.append(.save(key: key, value: data))
        if let result = stubbedSaveResults[key], case let .failure(error) = result {
            throw error
        }
    }

    func retrieve(forKey key: String) throws -> Data {
        receivedMessages.append(.retrieve(key: key))
        if let result = stubbedRetrievalResults[key] {
            switch result {
            case let .success(data): return data
            case let .failure(error): throw error
            }
        }
        throw NSError(domain: "test", code: 0)
    }

    func delete(forKey key: String) throws {
        receivedMessages.append(.delete(key: key))
        if let result = stubbedDeleteResults[key], case let .failure(error) = result {
            throw error
        }
    }

    // MARK: - Stubbing helpers

    func stubSave(forKey key: String, with result: Result<Void, Error>) {
        stubbedSaveResults[key] = result
    }

    func stubRetrieval(forKey key: String, with result: Result<Data, Error>) {
        stubbedRetrievalResults[key] = result
    }

    func stubDelete(forKey key: String, with result: Result<Void, Error>) {
        stubbedDeleteResults[key] = result
    }
}
