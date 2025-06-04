import Foundation

// MARK: - Segregated Interfaces (ISP)

public protocol TokenWriter {
    func save(tokenBundle: Token) async throws
}

public protocol TokenReader {
    func loadTokenBundle() async throws -> Token?
}

public protocol TokenDeleter {
    func deleteTokenBundle() async throws
}

// MARK: - Composed Interface for Full Storage Operations

public protocol TokenStorage: TokenWriter, TokenReader, TokenDeleter {
    // func migrate() async throws
}

// MARK: - Convenience Typealiases for Specific Use Cases

public typealias TokenPersistence = TokenReader & TokenWriter
public typealias TokenManager = TokenDeleter & TokenReader
