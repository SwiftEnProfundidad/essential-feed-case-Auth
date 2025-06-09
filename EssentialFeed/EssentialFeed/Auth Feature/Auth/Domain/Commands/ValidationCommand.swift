import Foundation

public final class ValidationCommand: RegistrationCommand {
    private let validator: RegistrationValidatorProtocol
    private let notifier: UserRegistrationNotifier?

    public init(validator: RegistrationValidatorProtocol, notifier: UserRegistrationNotifier? = nil) {
        self.validator = validator
        self.notifier = notifier
    }

    public func execute(_ context: RegistrationContext) async throws -> RegistrationContext {
        if let validationError = validator.validate(
            name: context.userData.name,
            email: context.userData.email,
            password: context.userData.password
        ) {
            notifier?.notifyRegistrationFailed(with: validationError)
            throw validationError
        }
        return context
    }
}
