import Foundation

public enum NetworkError: Error, Equatable {
    case invalidResponse
    case clientError(statusCode: Int)
    case serverError(statusCode: Int)
    case unknown
    case noConnectivity
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid server response."
        case let .clientError(statusCode):
            "Client error with status code: \(statusCode)."
        case let .serverError(statusCode):
            "Server error with status code: \(statusCode)."
        case .noConnectivity:
            "No internet connection."
        case .unknown:
            "An unknown error occurred."
        }
    }
}
