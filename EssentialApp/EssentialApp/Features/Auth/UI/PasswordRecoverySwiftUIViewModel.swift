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
    private let mainQueueDispatcher: (@escaping () -> Void) -> Void

    public var feedbackTitle: String {
        if isSuccess {
            "Éxito"
        } else {
            "Error"
        }
    }

    public init(recoveryUseCase: UserPasswordRecoveryUseCase) {
        self.recoveryUseCase = recoveryUseCase
        self.mainQueueDispatcher = { block in DispatchQueue.main.async(execute: block) }
    }

    public init(recoveryUseCase: UserPasswordRecoveryUseCase, mainQueueDispatcher: @escaping (@escaping () -> Void) -> Void) {
        self.recoveryUseCase = recoveryUseCase
        self.mainQueueDispatcher = mainQueueDispatcher
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
            self.mainQueueDispatcher { [weak self] in
                guard let self else { return }
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

    deinit {
        #if DEBUG
            print("PasswordRecoverySwiftUIViewModel deallocated")
        #endif
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
