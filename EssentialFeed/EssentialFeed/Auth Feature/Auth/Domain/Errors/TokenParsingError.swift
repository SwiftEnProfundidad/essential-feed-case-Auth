import Foundation

public enum TokenParsingError: Error, Equatable {
    case invalidData
    case missingToken
}
