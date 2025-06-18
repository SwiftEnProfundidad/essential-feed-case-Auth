import EssentialFeed
import SwiftUI

public final class PasswordRecoverySwiftUIViewModel: ObservableObject, PasswordRecoveryView {
    @Published public var email: String = "" {
        didSet { handleEmailChange(from: oldValue, to: email) }
    }

    @Published public var feedbackMessage: String = ""
    @Published public var isSuccess: Bool = false
    @Published public var showingFeedback: Bool = false

    private let recoveryUseCase: UserPasswordRecoveryUseCase
    private var lastRequestedEmail: String?

    public var feedbackTitle: String {
        if isSuccess {
            "Éxito"
        } else {
            "Error"
        }
    }

    public init(recoveryUseCase: UserPasswordRecoveryUseCase) {
        self.recoveryUseCase = recoveryUseCase
    }

    public func onFeedbackDismiss() {
        showingFeedback = false
    }

    public func recoverPassword() {
        guard !email.isEmpty else { return }
        lastRequestedEmail = email
        recoveryUseCase.recoverPassword(
            email: email,
            ipAddress: getCurrentIPAddress(),
            userAgent: getCurrentUserAgent()
        ) { [weak self] result in
            guard let self, self.email == self.lastRequestedEmail else { return }
            DispatchQueue.main.async {
                let viewModel = PasswordRecoveryPresenter.map(result)
                self.display(viewModel)
            }
        }
    }

    private func handleEmailChange(from oldValue: String, to newValue: String) {
        guard showingFeedback, oldValue != newValue else { return }
        feedbackMessage = ""
        showingFeedback = false
    }

    private func getCurrentIPAddress() -> String? {
        return nil
    }

    private func getCurrentUserAgent() -> String? {
        return "EssentialApp/1.0"
    }
}

// MARK: - PasswordRecoveryView

public extension PasswordRecoverySwiftUIViewModel {
    func display(_ viewModel: PasswordRecoveryViewModel) {
        feedbackMessage = viewModel.message
        isSuccess = viewModel.isSuccess
        showingFeedback = true
    }
}
