import Foundation

public final class RequestCreationCommand: RegistrationCommand {
    private let registrationEndpoint: URL

    public init(registrationEndpoint: URL) {
        self.registrationEndpoint = registrationEndpoint
    }

    public func execute(_ context: RegistrationContext) async throws -> RegistrationContext {
        var newContext = context
        var request = URLRequest(url: registrationEndpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "name": context.userData.name,
            "email": context.userData.email,
            "password": context.userData.password
        ])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        newContext.request = request
        return newContext
    }
}
