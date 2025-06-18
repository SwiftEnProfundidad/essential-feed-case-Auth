import Foundation

public final class BasicBotDetectionService: BotDetectionService {
    private let suspiciousUserAgents: Set<String>
    private let requestFrequencyTracker: RequestFrequencyTracker

    public init(suspiciousUserAgents: Set<String> = BasicBotDetectionService.defaultSuspiciousUserAgents, requestFrequencyTracker: RequestFrequencyTracker = InMemoryRequestFrequencyTracker()) {
        self.suspiciousUserAgents = suspiciousUserAgents
        self.requestFrequencyTracker = requestFrequencyTracker
    }

    public func analyzeRequest(ipAddress: String?, userAgent: String?, requestPattern: RequestPattern) -> BotDetectionResult {
        var suspiciousFactors: [String] = []
        var confidenceScore = 0.0

        if let userAgent {
            if userAgent.isEmpty {
                suspiciousFactors.append("empty_user_agent")
                confidenceScore += 0.4
            } else if suspiciousUserAgents.contains(where: { userAgent.lowercased().contains($0.lowercased()) }) {
                suspiciousFactors.append("suspicious_user_agent")
                confidenceScore += 0.6
            }
        } else {
            suspiciousFactors.append("missing_user_agent")
            confidenceScore += 0.3
        }

        if let ipAddress {
            let requestCount = requestFrequencyTracker.getRequestCount(for: ipAddress, in: .passwordRecovery, within: 300)
            if requestCount > 5 {
                suspiciousFactors.append("high_frequency_requests")
                confidenceScore += min(0.5, Double(requestCount) * 0.1)
            }

            requestFrequencyTracker.recordRequest(for: ipAddress, pattern: requestPattern)
        }

        if confidenceScore >= 0.8 {
            return .bot(confidence: confidenceScore)
        } else if confidenceScore >= 0.4 {
            return .suspicious(reason: suspiciousFactors.joined(separator: ", "))
        } else {
            return .human
        }
    }

    public static let defaultSuspiciousUserAgents: Set<String> = [
        "bot", "crawler", "spider", "scraper", "curl", "wget", "python", "java", "go-http-client", "okhttp", "postman"
    ]
}

public protocol RequestFrequencyTracker {
    func getRequestCount(for ipAddress: String, in pattern: RequestPattern, within seconds: TimeInterval) -> Int
    func recordRequest(for ipAddress: String, pattern: RequestPattern)
    func cleanOldRequests(cutoffTime: Date)
}

public final class InMemoryRequestFrequencyTracker: RequestFrequencyTracker {
    private actor RequestStorage {
        private var requests: [String: [RequestRecord]] = [:]

        func getRequests(for key: String) -> [RequestRecord] {
            requests[key] ?? []
        }

        func addRequest(for key: String, record: RequestRecord) {
            requests[key, default: []].append(record)
        }

        func cleanOldRequests(cutoffTime: Date) {
            for key in requests.keys {
                requests[key] = requests[key]?.filter { $0.timestamp > cutoffTime }
            }
        }
    }

    private let storage = RequestStorage()

    public init() {}

    public func getRequestCount(for ipAddress: String, in pattern: RequestPattern, within _: TimeInterval) -> Int {
        Task {
            let key = "\(ipAddress):\(pattern)"
            return await storage.getRequests(for: key).count
        }
        return 0
    }

    public func recordRequest(for ipAddress: String, pattern: RequestPattern) {
        Task {
            let key = "\(ipAddress):\(pattern)"
            let record = RequestRecord(timestamp: Date(), pattern: pattern)
            await storage.addRequest(for: key, record: record)
        }
    }

    public func cleanOldRequests(cutoffTime: Date) {
        Task {
            await storage.cleanOldRequests(cutoffTime: cutoffTime)
        }
    }
}

private struct RequestRecord {
    let timestamp: Date
    let pattern: RequestPattern
}
