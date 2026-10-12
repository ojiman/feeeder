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
    /// A record as it was stored, to bring back a deleted note.
    init(noteID: UUID, articleID: UUID, title: String, url: String?, summary: String, addedAt: Date) {
        key = noteID.uuidString + ":" + articleID.uuidString
        self.noteID = noteID; self.articleID = articleID; self.title = title; self.url = url; self.summary = summary; self.addedAt = addedAt
    }
}

public struct SendResult: Equatable, Sendable {
    public let noteID: UUID
    public let articleID: UUID
    public let before: String
    public let after: String
    public let createdNote: Bool
    public let createdLink: Bool
    public let sentAt: Date
}

extension ReaderStore {
    /// The text and the source record commit together. Reload failure is reported even after a successful save.
    public func sendArticle(_ articleID: UUID, to noteID: UUID?, block: String, newNoteTitle: String, at: Date) throws -> SendResult {
        try reloadIfNeeded()
        guard let article = article(id: articleID) else { throw NoteError.missingArticle }
        let target: Note
        if let noteID {
            guard let existing = note(id: noteID) else { throw NoteError.missingNote }
            target = existing
        } else {
            target = Note(at: at)
            context.insert(target)
        }
        let before = target.text
        let after = noteID == nil ? NoteInsertion.newNoteText(title: newNoteTitle, block: block) : NoteInsertion.appended(block: block, to: before)
        let createdLink = !noteArticles.contains { $0.noteID == target.id && $0.articleID == articleID }
        if createdLink { context.insert(NoteArticle(noteID: target.id, article: article, summary: recordedSummary(of: article, at: at), at: at)) }
        target.text = after; target.updatedAt = at
        let result = SendResult(noteID: target.id, articleID: articleID, before: before, after: after,
                                createdNote: noteID == nil, createdLink: createdLink, sentAt: at)
        try save(); try reload()
        return result
    }

    public func undoSend(_ result: SendResult, at: Date) throws -> Bool {
        try reloadIfNeeded()
        guard let target = note(id: result.noteID), target.text == result.after else { return false }
        let links = noteArticles.filter { $0.noteID == result.noteID }
        // A new note may have acquired another source without changing its text; undo must not delete that source.
        if result.createdNote && links.contains(where: { $0.articleID != result.articleID || $0.addedAt != result.sentAt }) { return false }
        if result.createdLink, let link = links.first(where: { $0.articleID == result.articleID && $0.addedAt == result.sentAt }) {
            context.delete(link)
        }
        if result.createdNote { context.delete(target) }
        else { target.text = result.before; target.updatedAt = at }
        try save()
        try reload()
        return true
    }

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
    /// Renames a note by changing its first line (the title is the first line, decision 0019), through the same save as typing.
    /// Returns whether anything changed: the same name, or an empty one, saves nothing.
    @discardableResult public func renameNote(id: UUID, to name: String, at: Date) throws -> Bool {
        try reloadIfNeeded()
        guard let note = note(id: id) else { throw NoteError.missingNote }
        guard let text = NoteTitle.renamed(note.text, to: name), text != note.text else { return false }
        try saveNote(noteID: id, text: text, at: at)
        return true
    }
    /// Deletes a note and its records. The result is a copy of everything that was removed (nil when there was no such note),
    /// to hand to `restoreNote` if the person takes it back (decision 0042).
    @discardableResult public func deleteNote(id: UUID) throws -> DeletedNote? {
        try reloadIfNeeded()
        guard let note = note(id: id) else { return nil }
        let links = noteArticles.filter { $0.noteID == id }
        let copy = DeletedNote(id: id, text: note.text, createdAt: note.createdAt, updatedAt: note.updatedAt,
                               links: links.map { DeletedNote.Link(articleID: $0.articleID, title: $0.title, url: $0.url, summary: $0.summary, addedAt: $0.addedAt) })
        for link in links { context.delete(link) }
        context.delete(note)
        try save()
        try reload()
        return copy
    }

    /// Brings a deleted note back with the same identity, text, dates and recorded articles. False when a note with that
    /// identity exists already (nothing is added twice). A failed save changes nothing.
    @discardableResult public func restoreNote(_ deleted: DeletedNote) throws -> Bool {
        try reloadIfNeeded()
        guard note(id: deleted.id) == nil else { return false }
        let note = Note(text: deleted.text, at: deleted.createdAt)
        note.id = deleted.id
        note.updatedAt = deleted.updatedAt
        context.insert(note)
        for link in deleted.links {
            context.insert(NoteArticle(noteID: deleted.id, articleID: link.articleID, title: link.title, url: link.url, summary: link.summary, addedAt: link.addedAt))
        }
        try save()
        try reload()
        return true
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
    private func recordedSummary(of article: Article, at: Date) -> String {
        isContentAvailable(article, at: at) ? article.summary.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }
    public func noteArticleCount(noteID: UUID) -> Int {
        _ = noteArticles
        return noteMembers[noteID]?.count ?? 0
    }
}
