import Foundation

public struct QuickBitExplanation: Codable, Equatable, Sendable {
    public let description: String
    public let recommendation: String

    public init(description: String, recommendation: String) {
        self.description = description
        self.recommendation = recommendation
    }
}
