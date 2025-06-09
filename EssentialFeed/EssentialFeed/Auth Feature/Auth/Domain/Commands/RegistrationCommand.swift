import Foundation

public protocol RegistrationCommand {
    func execute(_ context: RegistrationContext) async throws -> RegistrationContext
}
