import Foundation

/// Text for one-line fields (subscription names, folder names, note names, web addresses). A line break can arrive by
/// paste or by Option-Return; it must not end up inside a name.
public enum SingleLineText {
    /// A name to save: each line break becomes one space, empty lines vanish, and the ends are trimmed.
    public static func name(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// For a field while the person types: line breaks become a space, but nothing is trimmed, so typing a space still works.
    public static func lineBreaksRemoved(_ text: String) -> String {
        guard text.contains(where: \.isNewline) else { return text }
        var result = "", inBreak = false
        for character in text {
            if character.isNewline { if !inBreak { result.append(" "); inBreak = true } }
            else { result.append(character); inBreak = false }
        }
        return result
    }

    /// For a web address while the person types: an address has no white space, so all of it is removed.
    public static func addressLive(_ text: String) -> String {
        text.filter { !$0.isWhitespace && !$0.isNewline }
    }
}
