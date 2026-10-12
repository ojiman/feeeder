import Foundation

/// What a name typed into a sidebar row means (decision 0043): a new name, or nothing to do.
public enum NameEdit {
    /// The name to save, or nil when there is nothing to save: the edit was cancelled (Esc), the name is empty, or it did not change.
    public static func result(old: String, typed: String?) -> String? {
        guard let typed else { return nil }
        let name = SingleLineText.name(typed)
        return name.isEmpty || name == SingleLineText.name(old) ? nil : name
    }

    /// An untitled note shows 「新規ノート」 as a label; the field starts empty rather than with that label.
    public static func initialText(forNoteTitle title: String) -> String { title == NoteTitle.untitled ? "" : title }
}
