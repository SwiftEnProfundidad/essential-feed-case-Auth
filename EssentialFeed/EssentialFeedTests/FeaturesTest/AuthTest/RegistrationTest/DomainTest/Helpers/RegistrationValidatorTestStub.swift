import EssentialFeed
import Foundation

// MARK: - Helpers & Stubs

public final class RegistrationValidatorTestStub: RegistrationValidatorProtocol {
    var errorToReturn: RegistrationValidationError?

    public init(errorToReturn: RegistrationValidationError? = nil) {
        self.errorToReturn = errorToReturn
    }

    public func validate(name _: String, email _: String, password _: String) -> RegistrationValidationError? {
        errorToReturn
    }
}

final class RegistrationValidatorAlwaysValid: RegistrationValidatorProtocol {
    func validate(name _: String, email _: String, password _: String) -> RegistrationValidationError? {
        nil
    }
}
