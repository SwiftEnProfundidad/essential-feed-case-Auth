import EssentialFeed
import SwiftUI

public final class PasswordRecoverySwiftUIViewModel: ObservableObject, PasswordRecoveryViewProtocol {
	// Inputs
	@Published public var email: String = "" {
		didSet { handleEmailChange(from: oldValue, to: email) }
	}
	
	// Outputs
	@Published public var feedbackMessage: String = ""
	@Published public var isSuccess: Bool = false
	@Published public var showingFeedback: Bool = false
	
	private let recoveryUseCase: UserPasswordRecoveryUseCase
	public var presenter: PasswordRecoveryPresenter?
	private var lastRequestedEmail: String?
	
	public var feedbackTitle: String {
		isSuccess ? "Éxito" : "Error"
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
			guard let self = self, self.email == self.lastRequestedEmail else { return }
			self.presenter?.didRecoverPassword(with: result)
		}
	}
	
	private func handleEmailChange(from oldValue: String, to newValue: String) {
		guard showingFeedback, oldValue != newValue else { return }
		feedbackMessage = ""
		showingFeedback = false
	}
}

// MARK: - PasswordRecoveryViewProtocol
extension PasswordRecoverySwiftUIViewModel {
    public func display(_ viewModel: PasswordRecoveryViewModel) {
        feedbackMessage = viewModel.message
        isSuccess = viewModel.isSuccess
        showingFeedback = true
    }
}
