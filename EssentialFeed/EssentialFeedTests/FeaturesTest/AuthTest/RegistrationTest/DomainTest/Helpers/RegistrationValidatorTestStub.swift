
import EssentialFeed
import Foundation

// MARK: - Helpers & Stubs

public final class RegistrationValidatorTestStub: RegistrationValidatorProtocol {
    var errorToReturn: RegistrationValidationError?

    public init(errorToReturn: RegistrationValidationError? = nil) {
        self.errorToReturn = errorToReturn
    }

    public func validate(name: String, email: String, password: String) -> RegistrationValidationError? {
        return errorToReturn
    }
}

final class RegistrationValidatorAlwaysValid: RegistrationValidatorProtocol {
    func validate(name: String, email: String, password: String) -> RegistrationValidationError? {
        return nil
    }
}
