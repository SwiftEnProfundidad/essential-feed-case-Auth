import Foundation

public enum BotDetectionResult: Equatable {
    case human
    case suspicious(reason: String)
    case bot(confidence: Double)
}
