import Foundation
import SwiftData

public enum NoteError: LocalizedError {
    case missingNote, missingArticle
    public var errorDescription: String? {
        switch self {
        case .missingNote: "ノートが見つかりません。"
        case .missingArticle: "記事が見つかりません。"
        }
    }
}

@Model public final class Note {
    @Attribute(.unique) public var id: UUID
    /// The note itself: plain Markdown text, `#` lines are headings. Stored exactly as typed; no length limit.
    public var text: String = ""
    public var createdAt: Date
    public var updatedAt: Date
    public init(text: String = "", at: Date) {
        id = UUID(); self.text = text; createdAt = at; updatedAt = at
    }
    /// A note has no name of its own: its first line is its title (decision 0019).
    public var title: String { NoteTitle.make(from: text) }
}

@Model public final class NoteArticle {
    @Attribute(.unique) public var key: String
    public var noteID: UUID
    public var articleID: UUID
    /// Title, original URL and RSS summary as they were when the article joined the note.
    public var title: String
    public var url: String?
    public var summary: String
    public var addedAt: Date
    public init(noteID: UUID, article: Article, summary: String, at: Date) {
        key = noteID.uuidString + ":" + article.id.uuidString
        self.noteID = noteID; articleID = article.id; title = article.title; url = article.originalURL
        self.summary = summary; addedAt = at
    }
}

extension ReaderStore {
    public func note(id: UUID) -> Note? { notes.first { $0.id == id } }
    /// The list in the sidebar: the note that was edited last comes first; equal times keep a fixed order by ID.
    public var notesNewestEditFirst: [Note] {
        notes.sorted { $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt }
    }

    @discardableResult public func createNote(text: String = "", at: Date) throws -> Note {
        try reloadIfNeeded()
        let note = Note(text: text, at: at)
        context.insert(note)
        try save(); try reload()
        return note
    }
    /// The typing path: the note is saved as it is, once per change. An unknown note is an error, never a silent drop.
    public func saveNote(noteID: UUID, text: String, at: Date) throws {
        try reloadIfNeeded()
        guard let note = note(id: noteID) else { throw NoteError.missingNote }
        guard note.text != text else { return }
        note.text = text; note.updatedAt = at
        try save()
    }
    public func deleteNote(id: UUID) throws {
        try reloadIfNeeded()
        guard let note = note(id: id) else { return }
        for link in noteArticles where link.noteID == id { context.delete(link) }
        context.delete(note)
        try save()
        defer { onContentPolicyChanged?() }
        try reload()
    }

    @discardableResult public func addArticle(_ articleID: UUID, toNote noteID: UUID, at: Date) throws -> NoteArticle {
        try reloadIfNeeded()
        guard let note = note(id: noteID) else { throw NoteError.missingNote }
        guard let article = article(id: articleID) else { throw NoteError.missingArticle }
        if noteMembers[noteID]?.contains(articleID) == true,
           let existing = noteArticles.first(where: { $0.noteID == noteID && $0.articleID == articleID }) {
            return existing
        }
        let summary = recordedSummary(of: article, at: at)
        let link = NoteArticle(noteID: noteID, article: article, summary: summary, at: at)
        context.insert(link)
        note.updatedAt = at
        try save(); try reload()
        return link
    }
    public func removeArticle(_ articleID: UUID, fromNote noteID: UUID, at: Date) throws {
        try reloadIfNeeded()
        guard let link = noteArticles.first(where: { $0.noteID == noteID && $0.articleID == articleID }) else { return }
        context.delete(link)
        note(id: noteID)?.updatedAt = at
        try save()
        defer { onContentPolicyChanged?() }
        try reload()
    }

    public func noteArticleIDs(noteID: UUID, keeping: UUID? = nil) -> [UUID] {
        _ = noteArticles
        let members = noteMembers[noteID] ?? []
        guard !members.isEmpty || keeping != nil else { return [] }
        return articleIDs.filter { members.contains($0) || $0 == keeping }
    }
    public func isInAnyNote(articleID: UUID) -> Bool {
        _ = noteArticles
        return articleNoteIDs[articleID] != nil
    }
    @discardableResult public func toggleNote(_ noteID: UUID, for articleID: UUID, at: Date) throws -> NoteMembershipChange {
        try reloadIfNeeded()
        guard let note = note(id: noteID) else { throw NoteError.missingNote }
        let title = note.title
        if noteMembers[noteID]?.contains(articleID) == true {
            try removeArticle(articleID, fromNote: noteID, at: at)
            return .removed(noteTitle: title)
        }
        try addArticle(articleID, toNote: noteID, at: at)
        return .added(noteTitle: title)
    }
    /// Creates the note and its first article in one save, so a failure never leaves an empty new note behind.
    @discardableResult public func createNote(text: String = "", adding articleID: UUID, at: Date) throws -> Note {
        try reloadIfNeeded()
        guard let article = article(id: articleID) else { throw NoteError.missingArticle }
        let note = Note(text: text, at: at)
        context.insert(note)
        context.insert(NoteArticle(noteID: note.id, article: article, summary: recordedSummary(of: article, at: at), at: at))
        try save(); try reload()
        return note
    }
    private func recordedSummary(of article: Article, at: Date) -> String {
        isContentAvailable(article, at: at) ? article.summary.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }
    public func noteArticleCount(noteID: UUID) -> Int {
        _ = noteArticles
        return noteMembers[noteID]?.count ?? 0
    }
    public func noteIDs(containing articleID: UUID) -> [UUID] {
        _ = noteArticles
        guard let ids = articleNoteIDs[articleID] else { return [] }
        return notes.map(\.id).filter { ids.contains($0) }
    }

}

public enum NoteMembershipChange: Equatable, Sendable {
    case added(noteTitle: String)
    case removed(noteTitle: String)
}
