import SwiftUI
import EssentialFeed

public final class PasswordRecoverySwiftUIViewModel: ObservableObject, PasswordRecoveryView {
    // Inputs
    @Published var email: String = ""
    // Outputs
    @Published var feedbackMessage: String = ""
    @Published var isSuccess: Bool = false
    @Published var showingFeedback: Bool = false

    private let recoveryUseCase: UserPasswordRecoveryUseCase
    private var presenter: PasswordRecoveryPresenter?

    public init(recoveryUseCase: UserPasswordRecoveryUseCase) {
        self.recoveryUseCase = recoveryUseCase
        self.presenter = PasswordRecoveryPresenter(view: self)
    }

    func recoverPassword() {
        recoveryUseCase.recoverPassword(email: email) { [weak self] result in
            self?.presenter?.didRecoverPassword(with: result)
        }
    }

    func onFeedbackDismiss() {
        showingFeedback = false
    }

    var feedbackTitle: String {
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
