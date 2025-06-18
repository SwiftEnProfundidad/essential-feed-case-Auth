import EssentialFeed
import Foundation

public final class PasswordRecoveryAuditLoggerSpy: PasswordRecoveryAuditLogger, @unchecked Sendable {
    private let queue = DispatchQueue(label: "PasswordRecoveryAuditLoggerSpy", attributes: .concurrent)
    private var _logRecoveryAttemptCallCount = 0
    private var _loggedAuditLogs: [PasswordRecoveryAuditLog] = []

    public init() {}

    public var logRecoveryAttemptCallCount: Int {
        queue.sync { _logRecoveryAttemptCallCount }
    }

    public var loggedAuditLogs: [PasswordRecoveryAuditLog] {
        queue.sync { _loggedAuditLogs }
    }

    public func logRecoveryAttempt(_ auditLog: PasswordRecoveryAuditLog) async throws {
        queue.async(flags: .barrier) {
            self._logRecoveryAttemptCallCount += 1
            self._loggedAuditLogs.append(auditLog)
        }
    }
}
