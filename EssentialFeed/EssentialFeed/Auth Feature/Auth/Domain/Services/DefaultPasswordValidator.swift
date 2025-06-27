import Foundation

public final class DefaultPasswordValidator: PasswordValidator {
    private let minLength = 8
    private let specialCharacterSet = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:'<>,.?/")

    public init() {}

    public func validate(password: String) -> Result<Void, PasswordValidationError> {
        if password.count < minLength {
            return .failure(.tooShort)
        }

        if password.rangeOfCharacter(from: .uppercaseLetters) == nil {
            return .failure(.missingUppercaseLetter)
        }

        if password.rangeOfCharacter(from: .decimalDigits) == nil {
            return .failure(.missingNumber)
        }

        if password.rangeOfCharacter(from: specialCharacterSet) == nil {
            return .failure(.missingSpecialCharacter)
        }

        return .success(())
    }
}
