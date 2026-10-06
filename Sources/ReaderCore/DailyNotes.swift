import Foundation
import SwiftData

@Model public final class DailyNote {
    @Attribute(.unique) public var id: UUID
    public var start: Date
    public var end: Date
    public var timeZoneID: String
    public var day: String
    public var title: String
    public var text: String
    public var createdAt: Date
    public var updatedAt: Date
    public init(start: Date, end: Date, timeZoneID: String, day: String, at: Date) {
        id = UUID(); self.start = start; self.end = end; self.timeZoneID = timeZoneID; self.day = day
        title = day; text = ""; createdAt = at; updatedAt = at
    }
}

@Model public final class NoteScrap {
    @Attribute(.unique) public var key: String
    public var noteID: UUID
    public var articleID: UUID
    public var title: String
    public var url: String?
    public var summary: String
    public var coverageRaw: String
    public var savedAt: Date
    public var memo: String
    public init(noteID: UUID, article: Article, summary: String, at: Date) {
        key = noteID.uuidString + ":" + article.id.uuidString
        self.noteID = noteID; articleID = article.id; title = article.title; url = article.originalURL
        self.summary = summary; coverageRaw = (summary.isEmpty ? ContentCoverage.unavailable : .summaryOnly).rawValue
        savedAt = at; memo = ""
    }
}
