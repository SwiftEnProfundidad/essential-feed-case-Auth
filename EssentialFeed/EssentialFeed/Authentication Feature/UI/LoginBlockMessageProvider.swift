public protocol LoginBlockMessageProvider {
    func message(forAttempts attempts: Int, maxAttempts: Int) -> String
}

public struct DefaultLoginBlockMessageProvider: LoginBlockMessageProvider {
    public init() {}
    public func message(forAttempts attempts: Int, maxAttempts: Int) -> String {
        return "Too many attempts. Please wait 5 minutes or reset your password."
    }
}
