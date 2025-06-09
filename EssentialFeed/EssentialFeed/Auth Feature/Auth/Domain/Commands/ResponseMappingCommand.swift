import Foundation

public final class ResponseMappingCommand: RegistrationCommand {
    private let responseMapper: UserRegistrationResponseMapping

    public init(responseMapper: UserRegistrationResponseMapping) {
        self.responseMapper = responseMapper
    }

    public func execute(_ context: RegistrationContext) async throws -> RegistrationContext {
        guard let (data, httpResponse) = context.httpResponse else {
            throw RegistrationError.missingHTTPResponse
        }

        let result = await responseMapper.map(data: data, httpResponse: httpResponse, for: context.userData)

        switch result {
        case let .success(tokenAndUser):
            var newContext = context
            newContext.tokenAndUser = tokenAndUser
            return newContext
        case let .failure(error):
            throw error
        }
    }
}
