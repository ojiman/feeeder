import Foundation
import SwiftData

public enum DailyNoteError: LocalizedError {
    case missingArticle
    public var errorDescription: String? { "保存する記事が見つかりません。" }
}

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

extension ReaderStore {
    public func dailyNote(containing date: Date) -> DailyNote? {
        dailyNotes.filter { $0.start <= date && date < $0.end }.max {
            $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
    }
    @discardableResult public func scrap(articleID: UUID, at: Date, timeZone: TimeZone) throws -> NoteScrap {
        guard let article = article(id: articleID) else { throw DailyNoteError.missingArticle }
        let note: DailyNote
        if let existing = dailyNote(containing: at) { note = existing }
        else {
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
            let interval = calendar.dateInterval(of: .day, for: at)!
            let parts = calendar.dateComponents([.year, .month, .day], from: interval.start)
            let day = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
            note = DailyNote(start: interval.start, end: interval.end, timeZoneID: timeZone.identifier, day: day, at: at)
        }
        if let existing = scraps.first(where: { $0.noteID == note.id && $0.articleID == articleID }) { return existing }
        let summary = isContentAvailable(article, at: at) ? article.summary.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let scrap = NoteScrap(noteID: note.id, article: article, summary: summary, at: at)
        if !dailyNotes.contains(where: { $0.id == note.id }) { context.insert(note) }
        context.insert(scrap)
        note.updatedAt = at
        try save(); try reload()
        return scrap
    }
    public func saveDailyNote(id: UUID, text: String, at: Date) throws {
        guard let note = dailyNotes.first(where: { $0.id == id }) else { return }
        note.text = text; note.updatedAt = at; try save()
    }
    public func saveScrapMemo(key: String, memo: String, at: Date) throws {
        guard let scrap = scraps.first(where: { $0.key == key }) else { return }
        scrap.memo = memo
        dailyNotes.first { $0.id == scrap.noteID }?.updatedAt = at
        try save()
    }
    public func deleteDailyNote(id: UUID) throws {
        guard let note = dailyNotes.first(where: { $0.id == id }) else { return }
        for scrap in scraps where scrap.noteID == id { context.delete(scrap) }
        context.delete(note)
        try save(); try reload()
    }
    public func removeScrap(key: String) throws {
        guard let scrap = scraps.first(where: { $0.key == key }) else { return }
        context.delete(scrap); try save(); try reload()
    }
}
