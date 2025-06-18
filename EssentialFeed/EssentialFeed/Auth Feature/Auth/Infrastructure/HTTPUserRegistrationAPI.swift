import Foundation

public final class HTTPUserRegistrationAPI: UserRegistrationAPI {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func register(with _: UserRegistrationData) async -> Result<UserRegistrationResponse, UserRegistrationError> {
        .success(UserRegistrationResponse(userID: "test123", token: "fake-token", refreshToken: "fake-refresh"))
    }
}
