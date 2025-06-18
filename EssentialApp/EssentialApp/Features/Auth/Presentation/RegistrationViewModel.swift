import Combine
import Foundation

public final class RegistrationViewModel: ObservableObject {
    @Published public var email: String = ""
    @Published public var password: String = ""
    @Published public var confirmPassword: String = ""
    @Published public var errorMessage: String?
    @Published public var isLoading: Bool = false

    public init() {}

    @MainActor
    public func register() async {
        errorMessage = nil

        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Email cannot be empty"
            return
        }

        if password.isEmpty {
            errorMessage = "Password cannot be empty"
            return
        }

        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            return
        }

        do {
            isLoading = true
            // TODO: Implement actual registration logic with UserRegistrationUseCase
        }
        isLoading = false
    }
}
