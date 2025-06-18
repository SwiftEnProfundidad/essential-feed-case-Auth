import Foundation

public protocol PasswordRecoveryAuditLogger {
    func logRecoveryAttempt(_ auditLog: PasswordRecoveryAuditLog) async throws
}

public protocol PasswordRecoveryAuditReader {
    func getAuditLogs(for email: String) async throws -> [PasswordRecoveryAuditLog]
    func getAuditLogs(from startDate: Date, to endDate: Date) async throws -> [PasswordRecoveryAuditLog]
}
