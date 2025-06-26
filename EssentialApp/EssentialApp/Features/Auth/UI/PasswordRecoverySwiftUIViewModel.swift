import EssentialFeed
import SwiftUI

public final class PasswordRecoverySwiftUIViewModel: ObservableObject, PasswordRecoveryView {
    @Published public var email: String = "" {
        didSet { handleEmailChange(from: oldValue, to: email) }
    }

    @Published public var currentNotification: InAppNotification?
    @Published public var isPerformingRecovery: Bool = false

    private let recoveryUseCase: UserPasswordRecoveryUseCase
    private var lastRequestedEmail: String?
    private let mainQueueDispatcher: (@escaping () -> Void) -> Void

    public var feedbackTitle: String {
        String(localized: "PASSWORD_RECOVERY_SUCCESS_TITLE", bundle: .main)
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
        currentNotification = nil
    }

    public func recoverPassword() {
        guard !email.isEmpty else {
            currentNotification = InAppNotification(
                title: "Validation Error",
                message: "Please enter your email address.",
                type: .error,
                actionButton: "OK"
            )
            return
        }

        isPerformingRecovery = true
        lastRequestedEmail = email
        recoveryUseCase.recoverPassword(
            email: email,
            ipAddress: getCurrentIPAddress(),
            userAgent: getCurrentUserAgent()
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.email == self.lastRequestedEmail else { return }
                self.isPerformingRecovery = false
                let viewModel = PasswordRecoveryPresenter.map(result)
                self.display(viewModel)
            }
        }
    }

    private func handleEmailChange(from oldValue: String, to newValue: String) {
        guard currentNotification != nil, oldValue != newValue else { return }
        currentNotification = nil
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
        currentNotification = InAppNotification(
            title: viewModel.isSuccess ? "Success" : "Error",
            message: viewModel.message,
            type: viewModel.isSuccess ? .success : .error,
            actionButton: "OK"
        )
    }
}
