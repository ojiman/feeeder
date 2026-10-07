import Foundation
import SwiftData

public struct WeekRange: Sendable, Equatable {
    public let start: Date
    public let end: Date
    public let timeZoneID: String
    public let startDay: String
    public let endDay: String
}

public enum WeekCalendar {
    public static func range(containing date: Date, timeZone: TimeZone) -> WeekRange {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone; calendar.firstWeekday = 2; calendar.minimumDaysInFirstWeek = 4
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)!
        func day(_ date: Date) -> String {
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
        }
        return WeekRange(start: interval.start, end: interval.end, timeZoneID: timeZone.identifier,
                         startDay: day(interval.start), endDay: day(interval.end.addingTimeInterval(-1)))
    }
}

@Model public final class WeeklyPeriod {
    @Attribute(.unique) public var id: UUID
    @Attribute(.unique) public var weekKey: String
    public var start: Date
    public var end: Date
    public var timeZoneID: String
    public var startDay: String
    public var endDay: String
    public var range: WeekRange { WeekRange(start: start, end: end, timeZoneID: timeZoneID, startDay: startDay, endDay: endDay) }
    public init(range: WeekRange) {
        id = UUID(); weekKey = range.startDay; start = range.start; end = range.end
        timeZoneID = range.timeZoneID; startDay = range.startDay; endDay = range.endDay
    }
}

@Model public final class WeeklyNote {
    @Attribute(.unique) public var id: UUID
    public var weekID: UUID
    public var isDefault: Bool
    public var title: String
    public var text: String
    public var updatedAt: Date
    public init(weekID: UUID, title: String, isDefault: Bool, at: Date) {
        id = UUID(); self.weekID = weekID; self.title = title; self.isDefault = isDefault
        text = ""; updatedAt = at
    }
}

@Model public final class NoteSource {
    @Attribute(.unique) public var key: String
    public var noteID: UUID
    public var articleID: UUID
    public var title: String
    public var url: String?
    public var summary: String?
    public var coverageRaw: String?
    public var savedAt: Date?
    public init(noteID: UUID, article: Article) {
        key = noteID.uuidString + ":" + article.id.uuidString
        self.noteID = noteID; articleID = article.id; title = article.title; url = article.originalURL
    }
    public init(noteID: UUID, articleID: UUID, title: String, url: String?, summary: String, coverageRaw: String, savedAt: Date) {
        key = noteID.uuidString + ":" + articleID.uuidString
        self.noteID = noteID; self.articleID = articleID; self.title = title; self.url = url
        self.summary = summary; self.coverageRaw = coverageRaw; self.savedAt = savedAt
    }
}

extension ReaderStore {
    public func availableWeeks(at: Date, timeZone: TimeZone) -> [WeekRange] {
        var values = Dictionary(uniqueKeysWithValues: weeks.map { ($0.weekKey, $0.range) })
        let current = WeekCalendar.range(containing: at, timeZone: timeZone)
        let previous = WeekCalendar.range(containing: current.start.addingTimeInterval(-1), timeZone: timeZone)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let intentDates = articles.compactMap(\.starredAt) + scraps.map(\.savedAt)
        let readDays = Set((articles.compactMap { $0.firstReadAt } + intentDates).map { calendar.startOfDay(for: $0) })
        let ranges = [current, previous] + readDays.map { WeekCalendar.range(containing: $0, timeZone: timeZone) }
        for range in ranges where values[range.startDay] == nil { values[range.startDay] = range }
        return values.values.sorted { $0.start > $1.start }
    }
    public func createNote(in range: WeekRange, title: String, at: Date) throws -> WeeklyNote {
        let period = weeks.first { $0.weekKey == range.startDay } ?? WeeklyPeriod(range: range)
        context.insert(period)
        let isDefault = !notes.contains { $0.weekID == period.id && $0.isDefault }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = WeeklyNote(weekID: period.id, title: title.isEmpty ? "週の振り返り" : title, isDefault: isDefault, at: at)
        context.insert(note)
        try save(); try reload()
        return note
    }
    public func saveNote(id: UUID, text: String, at: Date) throws {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        note.text = text; note.updatedAt = at
        try save()
    }
    public func candidates(in range: WeekRange) -> [Article] {
        articles.filter { article in
            guard let read = article.firstReadAt else { return false }
            return range.start <= read && read < range.end
        }
    }
    public func adoptSources(noteID: UUID, articleIDs: [UUID]) throws {
        guard notes.contains(where: { $0.id == noteID }) else { return }
        for id in Set(articleIDs) {
            guard let article = articles.first(where: { $0.id == id }),
                  !noteSources.contains(where: { $0.noteID == noteID && $0.articleID == id }) else { continue }
            context.insert(NoteSource(noteID: noteID, article: article))
        }
        try save(); try reload()
    }
    public func weeklyCandidates(in range: WeekRange) -> [WeeklyCandidate] {
        let saved = Dictionary(grouping: scraps.filter { range.start <= $0.savedAt && $0.savedAt < range.end }, by: \.articleID)
        let starred = articles.filter { article in
            article.starredAt.map { range.start <= $0 && $0 < range.end } == true
        }
        let ids = Set(starred.map(\.id)).union(saved.keys)
        return ids.map { id in
            WeeklyCandidate(articleID: id, starredAt: starred.first { $0.id == id }?.starredAt,
                scraps: (saved[id] ?? []).sorted { $0.savedAt == $1.savedAt ? $0.key < $1.key : $0.savedAt < $1.savedAt })
        }.sorted {
            let left = $0.scraps.first?.savedAt ?? $0.starredAt ?? .distantPast
            let right = $1.scraps.first?.savedAt ?? $1.starredAt ?? .distantPast
            return left == right ? $0.articleID.uuidString < $1.articleID.uuidString : left < right
        }
    }
    public func adoptScraps(noteID: UUID, scrapKeys: [String]) throws {
        guard notes.contains(where: { $0.id == noteID }) else { return }
        var adopted = Set(noteSources.filter { $0.noteID == noteID }.map(\.articleID))
        for key in scrapKeys {
            guard let scrap = scraps.first(where: { $0.key == key }), !adopted.contains(scrap.articleID) else { continue }
            let source = NoteSource(noteID: noteID, articleID: scrap.articleID, title: scrap.title, url: scrap.url,
                summary: scrap.summary, coverageRaw: scrap.coverageRaw, savedAt: scrap.savedAt)
            context.insert(source); adopted.insert(scrap.articleID)
        }
        try save(); try reload()
    }
    public func deleteNote(id: UUID) throws {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        for source in noteSources where source.noteID == id { context.delete(source) }
        context.delete(note)
        try save(); try reload()
        onContentPolicyChanged?()
    }
}

public struct WeeklyCandidate {
    public let articleID: UUID
    public let starredAt: Date?
    public let scraps: [NoteScrap]
}
