import Foundation

/// Decision 0049: the hand-off to Claude is gone. Earlier versions kept copies of the note text in a `Handoffs` folder of the library
/// (each deleted after 24 hours by the hand-off code). Nothing deletes them any more, so the app removes the folder when it starts.
public enum LegacyHandoffFolder {
    /// Removes `Handoffs` from the library's folder. Returns whether there was one. A link with that name is removed, never what it
    /// points to. A failure is thrown, so that the caller can tell the person.
    @discardableResult
    public static func remove(in library: URL, using manager: FileManager = .default) throws -> Bool {
        let folder = library.appending(path: "Handoffs")
        // `fileExists` follows links; a broken link must still be removed, so ask for the item itself.
        guard (try? manager.attributesOfItem(atPath: folder.path)) != nil else { return false }
        try manager.removeItem(at: folder)
        return true
    }
}
