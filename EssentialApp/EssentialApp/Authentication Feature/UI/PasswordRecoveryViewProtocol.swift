import Foundation

public protocol PasswordRecoveryViewProtocol: AnyObject {
    func display(_ viewModel: PasswordRecoveryViewModel)
}

public struct PasswordRecoveryViewModel: Equatable {
    public let message: String
    public let isSuccess: Bool
    
    public init(message: String, isSuccess: Bool) {
        self.message = message
        self.isSuccess = isSuccess
    }
}
