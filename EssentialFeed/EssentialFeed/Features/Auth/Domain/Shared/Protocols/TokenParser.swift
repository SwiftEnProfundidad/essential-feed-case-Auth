import Foundation

public protocol TokenParser {
    func parse(from data: Data) throws -> Token
}
