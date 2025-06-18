import Combine
import EssentialFeed
import Foundation

public final class RegistrationViewModel: ObservableObject {
    @Published public var email: String = ""
    @Published public var password: String = ""
    @Published public var confirmPassword: String = ""
    @Published public var errorMessage: String?
    @Published public var isLoading: Bool = false

    private let userRegisterer: UserRegisterer?

    public init(userRegisterer: UserRegisterer? = nil) {
        self.userRegisterer = userRegisterer
    }

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

        guard let userRegisterer = userRegisterer else {
            isLoading = true
            isLoading = false
            return
        }

        do {
            isLoading = true
            let result = await userRegisterer.register(name: "", email: email, password: password)
            switch result {
            case .success:
                break
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}

private struct MockRegistrationService: RegistrationService {
    func register(name _: String, email _: String, password _: String) async -> UserRegistrationResult {
        return .failure(NSError(domain: "MockError", code: 0, userInfo: nil))
    }
}
