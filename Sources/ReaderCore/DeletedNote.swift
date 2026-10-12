import Foundation
import Observation

/// Everything a deleted note had, so it can be brought back (decision 0042).
public struct DeletedNote: Sendable, Equatable {
    public struct Link: Sendable, Equatable {
        public let articleID: UUID
        public let title: String
        public let url: String?
        public let summary: String
        public let addedAt: Date
    }
    public let id: UUID
    public let text: String
    public let createdAt: Date
    public let updatedAt: Date
    public let links: [Link]
}

/// The offer 「取り消す」 after a note was deleted: it holds the last deletion only, until it is taken or dismissed.
@Observable @MainActor public final class DeletedNoteOffer {
    public private(set) var deleted: DeletedNote?
    public init() {}

    /// A newer deletion replaces the older offer; nil (nothing was deleted) clears it.
    public func offer(_ note: DeletedNote?) { deleted = note }
    public func dismiss() { deleted = nil }

    /// Brings the note back and returns its id (nil when there is nothing to restore). If it fails, the offer stays.
    public func restore(in store: ReaderStore) throws -> UUID? {
        guard let note = deleted else { return nil }
        _ = try store.restoreNote(note)
        deleted = nil
        return note.id
    }
}
