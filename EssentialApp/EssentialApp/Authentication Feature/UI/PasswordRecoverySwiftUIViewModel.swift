import SwiftUI
import EssentialFeed

public final class PasswordRecoverySwiftUIViewModel: ObservableObject, PasswordRecoveryView {
    // Inputs
    @Published public var email: String = "" {
        didSet {
            if oldValue != email {
                feedbackMessage = ""
                showingFeedback = false
            }
        }
    }
    // Outputs
    @Published public var feedbackMessage: String = ""
    @Published public var isSuccess: Bool = false
    @Published public var showingFeedback: Bool = false

    private let recoveryUseCase: UserPasswordRecoveryUseCase
    public var presenter: PasswordRecoveryPresenter?

    public init(recoveryUseCase: UserPasswordRecoveryUseCase) {
        self.recoveryUseCase = recoveryUseCase
        self.presenter = PasswordRecoveryPresenter(view: self)
    }

    public func recoverPassword() {
        guard !email.isEmpty else { return }
        recoveryUseCase.recoverPassword(email: email) { [weak self] result in
            self?.presenter?.didRecoverPassword(with: result)
        }
    }

    public func onFeedbackDismiss() {
        showingFeedback = false
    }

    public var feedbackTitle: String {
        isSuccess ? "Éxito" : "Error"
    }
}

// MARK: - PasswordRecoveryView
extension PasswordRecoverySwiftUIViewModel {
	public func display(_ viewModel: PasswordRecoveryViewModel) {
        feedbackMessage = viewModel.message
        isSuccess = viewModel.isSuccess
        showingFeedback = true
    }
}
