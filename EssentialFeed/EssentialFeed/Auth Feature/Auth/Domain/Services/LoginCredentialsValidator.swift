import Foundation

public final class LoginCredentialsValidator {
    public init() {}

    public func validate(_ credentials: LoginCredentials) -> LoginError? {
        let email = credentials.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = credentials.password.trimmingCharacters(in: .whitespacesAndNewlines)

        if email.isEmpty || !isValidEmail(email) {
            return .invalidEmailFormat
        }
        if password.isEmpty || password.count < 6 {
            return .invalidPasswordFormat
        }
        return nil
    }

    public func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
