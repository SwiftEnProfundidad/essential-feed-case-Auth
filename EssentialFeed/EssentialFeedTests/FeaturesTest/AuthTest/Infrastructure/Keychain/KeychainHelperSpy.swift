
import EssentialFeed

final class KeychainHelperSpy: KeychainStore {
    private(set) var setCalls: [(value: String, key: String)] = []
    private(set) var getCalls: [String] = []
    private(set) var deleteCalls: [String] = []
    var stubbedValue: String?

    func set(_ value: String, for key: String) {
        setCalls.append((value, key))
    }

    func get(_ key: String) -> String? {
        getCalls.append(key)
        return stubbedValue
    }

    func delete(_ key: String) {
        deleteCalls.append(key)
    }
}
