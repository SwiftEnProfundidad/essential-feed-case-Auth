import Foundation

public final class PasswordRecoveryAuditMemoryStore: PasswordRecoveryAuditLogger, PasswordRecoveryAuditReader, @unchecked Sendable {
    private var auditLogs: [PasswordRecoveryAuditLog] = []
    private let queue = DispatchQueue(label: "PasswordRecoveryAuditMemoryStore", attributes: .concurrent)

    public init() {}

    public func logRecoveryAttempt(_ auditLog: PasswordRecoveryAuditLog) async throws {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.auditLogs.append(auditLog)
                continuation.resume()
            }
        }
    }

    public func getAuditLogs(for email: String) async throws -> [PasswordRecoveryAuditLog] {
        await withCheckedContinuation { continuation in
            queue.async {
                let logs = self.auditLogs.filter { $0.email == email }
                continuation.resume(returning: logs)
            }
        }
    }

    public func getAuditLogs(from startDate: Date, to endDate: Date) async throws -> [PasswordRecoveryAuditLog] {
        await withCheckedContinuation { continuation in
            queue.async {
                let logs = self.auditLogs.filter { log in
                    log.timestamp >= startDate && log.timestamp <= endDate
                }
                continuation.resume(returning: logs)
            }
        }
    }
}
