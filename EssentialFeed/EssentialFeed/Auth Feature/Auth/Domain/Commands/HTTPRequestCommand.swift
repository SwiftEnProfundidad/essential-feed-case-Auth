import Foundation

public final class HTTPRequestCommand: RegistrationCommand {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func execute(_ context: RegistrationContext) async throws -> RegistrationContext {
        guard let protectedRequest = context.protectedRequest else {
            throw RegistrationError.missingProtectedRequest
        }

        var newContext = context
        newContext.httpResponse = try await httpClient.send(protectedRequest)
        return newContext
    }
}
