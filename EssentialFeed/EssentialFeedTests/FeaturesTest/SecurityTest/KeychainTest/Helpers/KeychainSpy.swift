
import EssentialFeed
import Foundation

// MARK: - KeychainSaveSpy

public final class KeychainSaveSpy: KeychainSavable {
    public var receivedKey: String?
    public var receivedData: Data?
    public var saveResult: KeychainSaveResult = .success
    public var saveCalled = false
    public var saveCallCount = 0
    public var lastData: Data?
    public var lastKey: String?
    public var simulatedError: Int?

    public init() {}

    public func save(data: Data, forKey key: String) -> KeychainSaveResult {
        if let error = simulatedError {
            if error == -25299 {
                return .duplicateItem
            }
            return .failure
        }
        saveCalled = true
        saveCallCount += 1
        lastData = data
        lastKey = key
        receivedKey = key
        receivedData = data
        return saveResult
    }

    public func load(forKey key: String) -> Data? {
        receivedKey == key ? receivedData : nil
    }
}

// MARK: - KeychainDeleteSpy

public final class KeychainDeleteSpy: KeychainSavable, KeychainDeletable {
    public var deleteCalled = false
    public var lastDeletedKey: String?
    public var deleteResult: Bool = true
    public var simulatedDeleteError: Int?

    public init() {}

    public func delete(forKey key: String) -> Bool {
        deleteCalled = true
        lastDeletedKey = key
        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if simulatedDeleteError != nil {
            return false // Simula error real
        }
        return deleteResult
    }

    public func save(data _: Data, forKey _: String) -> KeychainSaveResult { .success }
    public func load(forKey _: String) -> Data? { nil }
}

// MARK: - KeychainUpdateSpy

public final class KeychainUpdateSpy: KeychainSavable, KeychainUpdatable {
    public var customUpdateHandler: ((Data, String) -> Bool)?
    public var updateCalled = false
    public var lastUpdatedKey: String?
    public var lastUpdatedData: Data?
    public var updateStatus: OSStatus = errSecDuplicateItem // -25299 por defecto
    public var existingKeys: (() -> Set<String>)? // Permite consultar las claves existentes

    public init() {}

    // MARK: - KeychainUpdatable

    public func update(data: Data, forKey key: String) -> OSStatus {
        updateCalled = true
        lastUpdatedKey = key
        lastUpdatedData = data
        if let handler = customUpdateHandler {
            return handler(data, key) ? errSecSuccess : errSecDuplicateItem
        }
        if let keys = existingKeys, !keys().contains(key) {
            return errSecDuplicateItem // -25299
        }
        return updateStatus == errSecSuccess ? errSecSuccess : errSecDuplicateItem
    }

    // MARK: - KeychainSavable

    public func save(data _: Data, forKey _: String) -> KeychainSaveResult { .success }
    public func load(forKey _: String) -> Data? { nil }
}

// MARK: - Helper Factory (Global)

func makeKeychainFullSpy(strictMode: Bool = true) -> KeychainFullSpy {
    let spy = KeychainFullSpy()
    spy.strictMode = strictMode
    return spy
}

public protocol KeychainSpyAux {
    var saveResult: KeychainSaveResult { get set }
    var updateStatus: OSStatus { get set }
}

// MARK: - KeychainFullSpy

public final class KeychainFullSpy: KeychainFull, KeychainSpyAux {
    // MARK: - Properties

    public var forceValidationFailForKey: String?
    public var strictMode = false
    public var deleteSpy = KeychainDeleteSpy()
    public var saveSpy = KeychainSaveSpy()
    public var updateSpy = KeychainUpdateSpy()
    var storage: [String: Data] = [:]
    let storageLock = NSRecursiveLock()
    var errorByKey: [String: Int] = [:]
    var _loadResult: Data??

    // MARK: - Protocol Properties

    public var saveResult: KeychainSaveResult {
        get { saveSpy.saveResult }
        set { saveSpy.saveResult = newValue }
    }

    public var updateStatus: OSStatus {
        get { updateSpy.updateStatus }
        set { updateSpy.updateStatus = newValue }
    }

    public var loadResult: Data?? {
        get { _loadResult }
        set { _loadResult = newValue }
    }

    // MARK: - Forwarded Properties

    public var customUpdateHandler: ((Data, String) -> Bool)? {
        get { updateSpy.customUpdateHandler }
        set { updateSpy.customUpdateHandler = newValue }
    }

    public var updateCalled: Bool {
        get { updateSpy.updateCalled }
        set { updateSpy.updateCalled = newValue }
    }

    public var lastUpdatedData: Data? {
        get { updateSpy.lastUpdatedData }
        set { updateSpy.lastUpdatedData = newValue }
    }

    public var lastUpdatedKey: String? {
        get { updateSpy.lastUpdatedKey }
        set { updateSpy.lastUpdatedKey = newValue }
    }

    public var deleteCalled: Bool {
        get { deleteSpy.deleteCalled }
        set { deleteSpy.deleteCalled = newValue }
    }

    public var lastDeletedKey: String? {
        get { deleteSpy.lastDeletedKey }
        set { deleteSpy.lastDeletedKey = newValue }
    }

    // MARK: - Hooks

    public var willValidateAfterSave: ((String) -> Void)?

    // MARK: - Init

    public init() {}

    // MARK: - KeychainFull

    public func save(data: Data, forKey key: String) -> KeychainSaveResult {
        if !strictMode { return saveSpy.save(data: data, forKey: key) }
        guard isValidInput(key: key, data: data) else { return .failure }
        storageLock.lock()
        defer { storageLock.unlock() }
        guard ensureNoDuplicate(forKey: key) else { return .failure }
        return performSave(data: data, forKey: key)
    }

    private func isValidInput(key: String, data: Data) -> Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !data.isEmpty
    }

    private func ensureNoDuplicate(forKey key: String) -> Bool {
        !storage.keys.contains(key) || deleteUnlocked(forKey: key)
    }

    private func performSave(data: Data, forKey key: String) -> KeychainSaveResult {
        switch saveSpy.save(data: data, forKey: key) {
        case .success:
            validateAfterSave(data: data, forKey: key)
        case .duplicateItem:
            handleDuplicate(data: data, forKey: key)
        case .failure:
            .failure
        }
    }

    private func validateAfterSave(data: Data, forKey key: String) -> KeychainSaveResult {
        storage[key] = data
        willValidateAfterSave?(key)
        let validationData: Data? = loadResult ?? storage[key]
        guard validationData != nil else {
            storage.removeValue(forKey: key)
            return .failure
        }
        return .success
    }

    private func handleDuplicate(data: Data, forKey key: String) -> KeychainSaveResult {
        for _ in 0 ..< 2 {
            let updateStatus = update(data: data, forKey: key)
            if updateStatus == errSecSuccess {
                let result = validateAfterSave(data: data, forKey: key)
                if result == .success {
                    return .success // Si update y validación tienen éxito, devuelve success
                }
            } else if updateStatus == errSecDuplicateItem {
                storage.removeValue(forKey: key)
                return .duplicateItem
            } else {
                storage.removeValue(forKey: key)
                return .failure
            }
        }
        storage.removeValue(forKey: key)
        return .failure
    }

    public func update(data: Data, forKey key: String) -> OSStatus {
        if let handler = customUpdateHandler {
            if handler(data, key) {
                storageLock.lock()
                storage[key] = data
                storageLock.unlock()
                return errSecSuccess
            } else {
                return errSecDuplicateItem
            }
        }
        storageLock.lock()
        defer { storageLock.unlock() }
        if !storage.keys.contains(key) {
            return errSecDuplicateItem
        }
        if updateStatus == errSecSuccess {
            storage[key] = data
            return errSecSuccess
        }
        return errSecDuplicateItem
    }

    public func delete(forKey key: String) -> Bool {
        storageLock.lock()
        defer { storageLock.unlock() }
        return deleteUnlocked(forKey: key)
    }

    public func load(forKey key: String) -> Data? {
        if let override = _loadResult {
            return override
        }
        if let forceKey = forceValidationFailForKey, forceKey == key {
            return nil
        }
        storageLock.lock()
        defer { storageLock.unlock() }
        return storage[key]
    }

    public func resetLoadResultOverride() {
        _loadResult = nil
    }

    private func deleteUnlocked(forKey key: String) -> Bool {
        let deleted = deleteSpy.delete(forKey: key)
        if deleted {
            storage.removeValue(forKey: key)
        }
        return deleted
    }

    public func simulateCorruption(forKey key: String) {
        storageLock.lock()
        storage[key] = nil
        storageLock.unlock()
    }
}
