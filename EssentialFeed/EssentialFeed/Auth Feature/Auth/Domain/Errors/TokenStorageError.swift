import Foundation

public enum TokenStorageError: Error, Equatable {
    case encodingFailed(Error?)
    case decodingFailed(Error?)

    public static func == (lhs: TokenStorageError, rhs: TokenStorageError) -> Bool {
        switch (lhs, rhs) {
        case let (.encodingFailed(lhsError), .encodingFailed(rhsError)):
            (lhsError == nil && rhsError == nil) || (lhsError != nil && rhsError != nil)
        case let (.decodingFailed(lhsError), .decodingFailed(rhsError)):
            (lhsError == nil && rhsError == nil) || (lhsError != nil && rhsError != nil)
        default:
            false
        }
    }
}
