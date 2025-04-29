public struct PasswordRecoveryViewModel {
    public let message: String
    public let isSuccess: Bool
    
    public init(message: String, isSuccess: Bool) {
        self.message = message
        self.isSuccess = isSuccess
    }
}
