import EssentialFeed
import Foundation
import Security

final class KeychainFullSpy: KeychainFull {
    private(set) var saveCallCount = 0
    private(set) var receivedSaveData: Data?
    private(set) var receivedSaveKey: String?
    var saveResultToReturn: KeychainSaveResult = .success
    var saveCalled: Bool { saveCallCount > 0 }

    private(set) var loadCallCount = 0
    private(set) var receivedLoadKey: String?
    var stubbedLoadDataForKey: [String: Data?] = [:]

    private(set) var deleteCallCount = 0
    private(set) var receivedDeleteKey: String?
    var deleteResultToReturn: Bool = true
    var deleteCalled: Bool { deleteCallCount > 0 }

    private(set) var updateCallCount = 0
    private(set) var receivedUpdateData: Data?
    private(set) var receivedUpdateKey: String?
    var updateStatusToReturn: OSStatus = errSecSuccess
    var updateCalled: Bool { updateCallCount > 0 }

    private var _willValidate: ((String) -> Void)?
    var willValidateAfterSave: ((String) -> Void)? {
        get { _willValidate }
        set {
            guard let block = newValue else {
                _willValidate = nil
                return
            }
            _willValidate = { [weak self] key in
                block(key)
                _ = self
            }
        }
    }

    var maxRetriesForDuplicate: Int = 2

    private var storage: [String: Data] = [:]
    private let lock = NSRecursiveLock()

    func save(data: Data, forKey key: String) -> KeychainSaveResult {
        lock.lock(); defer { lock.unlock() }

        saveCallCount += 1
        receivedSaveData = data
        receivedSaveKey = key

        if saveResultToReturn == .success {
            storage[key] = data
            stubbedLoadDataForKey[key] = data
            _willValidate?(key)
            _willValidate = nil
            return storage[key] == nil ? .failure : .success
        }

        return saveResultToReturn
    }

    func load(forKey key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        loadCallCount += 1
        receivedLoadKey = key
        if let stub = stubbedLoadDataForKey[key] { return stub }
        return storage[key]
    }

    func delete(forKey key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        deleteCallCount += 1
        receivedDeleteKey = key
        if deleteResultToReturn {
            storage[key] = nil
            stubbedLoadDataForKey[key] = nil
        }
        return deleteResultToReturn
    }

    func update(data: Data, forKey key: String) -> OSStatus {
        lock.lock(); defer { lock.unlock() }
        updateCallCount += 1
        receivedUpdateData = data
        receivedUpdateKey = key

        guard updateStatusToReturn == errSecSuccess else { return updateStatusToReturn }

        storage[key] = data
        stubbedLoadDataForKey[key] = data
        _willValidate?(key)
        _willValidate = nil

        return storage[key] == nil ? errSecAuthFailed : errSecSuccess
    }

    // MARK: ‑ Helpers

    func simulateCorruption(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        storage[key] = nil
        stubbedLoadDataForKey[key] = nil
    }
}
