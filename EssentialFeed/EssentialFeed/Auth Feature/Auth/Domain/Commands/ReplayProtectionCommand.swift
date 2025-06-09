import Foundation

public final class ReplayProtectionCommand: RegistrationCommand {
    private let replayProtector: ReplayAttackProtector

    public init(replayProtector: ReplayAttackProtector) {
        self.replayProtector = replayProtector
    }

    public func execute(_ context: RegistrationContext) async throws -> RegistrationContext {
        guard let request = context.request else {
            throw RegistrationError.missingRequest
        }

        var newContext = context
        newContext.protectedRequest = try await replayProtector.protectRequest(request)
        return newContext
    }
}
