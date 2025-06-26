import Foundation

public struct InAppNotification: Equatable {
    public let title: String
    public let message: String
    public let type: NotificationType
    public let actionButton: String?

    public init(title: String, message: String, type: InAppNotification.NotificationType, actionButton: String?) {
        self.title = title
        self.message = message
        self.type = type
        self.actionButton = actionButton
    }

    public enum NotificationType: Equatable {
        case success
        case error
        case warning
        case info
    }
}
