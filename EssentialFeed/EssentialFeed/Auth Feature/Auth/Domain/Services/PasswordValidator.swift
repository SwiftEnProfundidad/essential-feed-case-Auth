import Foundation

public enum PasswordValidationError: Error, Equatable {
    case tooShort
    case missingUppercaseLetter
    case missingNumber
    case missingSpecialCharacter
}

public protocol PasswordValidator {
    func validate(password: String) -> Result<Void, PasswordValidationError>
}
