import Foundation

public enum ContentCoverage: String, Sendable, Codable {
    case feedProvided, extracted, summaryOnly, unavailable
}

public struct ArticleContent: Sendable, Equatable {
    public let articleID: UUID
    public let text: String
    public let paragraphs: [String]
    public let summary: String
    public let coverage: ContentCoverage
    public let originalURL: URL?
    public let bodyParagraphs: [BodyParagraph]
    public init(articleID: UUID, text: String, summary: String, coverage: ContentCoverage, originalURL: URL?, bodyParagraphs: [BodyParagraph]? = nil) {
        self.articleID = articleID; self.text = text
        self.paragraphs = bodyParagraphs?.map(\.text) ?? text.components(separatedBy: "\n\n").filter { !$0.isEmpty }; self.summary = summary
        self.coverage = coverage; self.originalURL = originalURL
        self.bodyParagraphs = bodyParagraphs ?? self.paragraphs.map { BodyParagraph(text: $0) }
    }
}
