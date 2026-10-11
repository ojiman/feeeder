import Foundation

/// The end rules for the previous and next article buttons of the note panel.
public enum NoteArticleSwitcher {
    /// Previous (-1) and next (+1) are possible when the shown article is not at that end. With nothing shown, both open the first one.
    public static func canMove(_ offset: Int, from selection: UUID?, in ids: [UUID]) -> Bool {
        guard !ids.isEmpty else { return false }
        guard let selection, let index = ids.firstIndex(of: selection) else { return true }
        return ids.indices.contains(index + offset)
    }
}
