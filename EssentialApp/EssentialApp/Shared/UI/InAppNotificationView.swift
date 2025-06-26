import EssentialFeed
import SwiftUI

public struct InAppNotificationView: View {
    let title: String
    let message: String
    let type: InAppNotification.NotificationType
    let actionButtonTitle: String
    let onAction: () -> Void

    public init(title: String, message: String, type: InAppNotification.NotificationType, actionButtonTitle: String, onAction: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.type = type
        self.actionButtonTitle = actionButtonTitle
        self.onAction = onAction
    }

    private var backgroundColor: Color {
        switch type {
        case .success: return Color.green.opacity(0.1)
        case .error: return Color.red.opacity(0.1)
        case .warning: return Color.orange.opacity(0.1)
        case .info: return Color.blue.opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch type {
        case .success: return Color.green
        case .error: return Color.red
        case .warning: return Color.orange
        case .info: return Color.blue
        }
    }

    private var iconName: String {
        switch type {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(borderColor)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }

            HStack {
                Spacer()
                Button(actionButtonTitle) {
                    onAction()
                }
                .foregroundColor(borderColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(borderColor.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}
