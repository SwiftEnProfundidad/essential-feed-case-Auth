import EssentialFeed
import Foundation

final class KeychainMigrationManagerSpy {
    private(set) var attemptMigrationCallCount = 0
    private(set) var attemptMigrationArgs: [(data: Data, key: String)] = []
    var attemptMigrationResult: Result<Data, Error> = .failure(KeychainError.migrationFailedBadFormat)

    func attemptMigration(for data: Data, key: String) throws -> Data {
        attemptMigrationCallCount += 1
        attemptMigrationArgs.append((data, key))

        switch attemptMigrationResult {
        case let .success(migratedData):
            return migratedData
        case let .failure(error):
            throw error
        }
    }
}
