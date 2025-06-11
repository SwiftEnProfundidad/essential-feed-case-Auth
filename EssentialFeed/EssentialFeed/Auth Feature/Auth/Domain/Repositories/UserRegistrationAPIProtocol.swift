import Foundation

public protocol UserRegistrationAPI {
    func register(with data: UserRegistrationData)
        async -> Result<UserRegistrationResponse, UserRegistrationError>
}
