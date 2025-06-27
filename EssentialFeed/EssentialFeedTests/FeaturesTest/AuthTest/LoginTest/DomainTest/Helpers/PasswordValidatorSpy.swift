import EssentialFeed
import Foundation

class PasswordValidatorSpy: PasswordValidator {
    private var results: [Result<Void, PasswordValidationError>] = []
    private(set) var validatedPasswords: [String] = []

    func stub(with result: Result<Void, PasswordValidationError>) {
        results.append(result)
    }

    func validate(password: String) -> Result<Void, PasswordValidationError> {
        validatedPasswords.append(password)
        return results.isEmpty ? .success(()) : results.removeFirst()
    }
}
