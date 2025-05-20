public protocol KeychainStore {
    func get(_ key: String) -> String?
    @discardableResult
    func save(_ value: String, for key: String) -> Bool
    @discardableResult
    func delete(_ key: String) -> Bool
}
