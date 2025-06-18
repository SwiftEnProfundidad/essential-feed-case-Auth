import EssentialFeed
import XCTest

final class PasswordRecoveryAuditLoggerTests: XCTestCase {
    func test_logRecoveryAttempt_storesAuditLogWithAllDetails() async throws {
        let (sut, _) = makeSUT()
        let auditLog = PasswordRecoveryAuditLog(email: "test@example.com", ipAddress: "192.168.1.1", userAgent: "Mozilla/5.0", outcome: .success)

        try await sut.logRecoveryAttempt(auditLog)

        let logs = try await sut.getAuditLogs(for: "test@example.com")
        XCTAssertEqual(logs.count, 1, "Should store one audit log")
        XCTAssertEqual(logs.first?.email, "test@example.com", "Should store correct email")
        XCTAssertEqual(logs.first?.ipAddress, "192.168.1.1", "Should store correct IP address")
        XCTAssertEqual(logs.first?.userAgent, "Mozilla/5.0", "Should store correct user agent")
        XCTAssertEqual(logs.first?.outcome, .success, "Should store correct outcome")
    }

    func test_getAuditLogs_returnsLogsForSpecificEmail() async throws {
        let (sut, _) = makeSUT()
        let log1 = PasswordRecoveryAuditLog(email: "user1@example.com", outcome: .success)
        let log2 = PasswordRecoveryAuditLog(email: "user2@example.com", outcome: .emailNotFound)
        let log3 = PasswordRecoveryAuditLog(email: "user1@example.com", outcome: .rateLimitExceeded)

        try await sut.logRecoveryAttempt(log1)
        try await sut.logRecoveryAttempt(log2)
        try await sut.logRecoveryAttempt(log3)

        let logsForUser1 = try await sut.getAuditLogs(for: "user1@example.com")
        XCTAssertEqual(logsForUser1.count, 2, "Should return logs only for specific email")
        XCTAssertTrue(logsForUser1.allSatisfy { $0.email == "user1@example.com" }, "Should return logs only for requested email")
    }

    func test_getAuditLogs_returnsLogsWithinDateRange() async throws {
        let (sut, _) = makeSUT()
        let yesterday = Date().addingTimeInterval(-86400)
        let today = Date()
        let tomorrow = Date().addingTimeInterval(86400)

        let log1 = PasswordRecoveryAuditLog(email: "test@example.com", timestamp: yesterday, outcome: .success)
        let log2 = PasswordRecoveryAuditLog(email: "test@example.com", timestamp: today, outcome: .emailNotFound)
        let log3 = PasswordRecoveryAuditLog(email: "test@example.com", timestamp: tomorrow, outcome: .rateLimitExceeded)

        try await sut.logRecoveryAttempt(log1)
        try await sut.logRecoveryAttempt(log2)
        try await sut.logRecoveryAttempt(log3)

        let logsInRange = try await sut.getAuditLogs(from: yesterday.addingTimeInterval(-3600), to: today.addingTimeInterval(3600))
        XCTAssertEqual(logsInRange.count, 2, "Should return logs within date range")
        XCTAssertTrue(logsInRange.contains(where: { $0.timestamp == yesterday }), "Should include yesterday's log")
        XCTAssertTrue(logsInRange.contains(where: { $0.timestamp == today }), "Should include today's log")
        XCTAssertFalse(logsInRange.contains(where: { $0.timestamp == tomorrow }), "Should not include tomorrow's log")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: PasswordRecoveryAuditMemoryStore, store: PasswordRecoveryAuditMemoryStore) {
        let sut = PasswordRecoveryAuditMemoryStore()
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, sut)
    }
}
