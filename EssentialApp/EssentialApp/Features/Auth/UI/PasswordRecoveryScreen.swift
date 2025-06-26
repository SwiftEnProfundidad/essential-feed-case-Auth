import SwiftUI

public struct PasswordRecoveryScreen: View {
    @ObservedObject var viewModel: PasswordRecoverySwiftUIViewModel

    public init(viewModel: PasswordRecoverySwiftUIViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            TextField("Email address", text: $viewModel.email)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Recover password") {
                viewModel.recoverPassword()
            }
            .modifier(BorderedProminentIfAvailable())

            if let notification = viewModel.currentNotification {
                InAppNotificationView(
                    title: notification.title,
                    message: notification.message,
                    type: notification.type,
                    actionButtonTitle: notification.actionButton ?? "OK",
                    onAction: {
                        viewModel.onFeedbackDismiss()
                    }
                )
            }
        }
        .padding()
    }
}

public struct BorderedProminentIfAvailable: ViewModifier {
    public func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(DefaultButtonStyle())
        }
    }
}
