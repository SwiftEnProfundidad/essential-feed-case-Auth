
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
    public var presenter: PasswordRecoveryPresenter?
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

    public func setPresenter(_ presenter: PasswordRecoveryPresenter) {
        self.presenter = presenter
    }

    public func onFeedbackDismiss() {
        showingFeedback = false
    }

    public func recoverPassword() {
        guard !email.isEmpty else { return }
        lastRequestedEmail = email
        recoveryUseCase.recoverPassword(email: email) { [weak self] (result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) in
            guard let self, self.email == self.lastRequestedEmail else { return }
            self.presenter?.didRecoverPassword(with: result)
        }
    }

    private func handleEmailChange(from oldValue: String, to newValue: String) {
        guard showingFeedback, oldValue != newValue else { return }
        feedbackMessage = ""
        showingFeedback = false
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
