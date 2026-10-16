import Foundation

/// The text that 「記事をノートに送る」 puts into the note (specification 3.3, decision 0059): the article's source as one Markdown
/// link, or the selected text as a quotation followed by that link. Only the text: the line breaks around it depend on where it goes in
/// the note, and the caller decides that.
public enum NoteClip {
    /// The text to insert, or nil when the article has neither a title nor a URL (the command then does nothing). A selection that is
    /// empty or only spaces counts as no selection. A shown translation is the caller's business: it passes no selection then.
    public static func text(title: String?, url: String?, selection: String?) -> String? {
        guard let source = sourceLine(title: title, url: url) else { return nil }
        let lines = selectionLines(selection)
        guard !lines.isEmpty else { return source }
        return (lines.map { $0.isEmpty ? ">" : "> " + $0 } + ["> — " + source]).joined(separator: "\n")
    }

    /// `[Title](URL)`; the URL alone without a title, the title alone without a URL.
    static func sourceLine(title: String?, url: String?) -> String? {
        let title = title.map(oneLine).flatMap { $0.isEmpty ? nil : escaped($0) }
        let url = url?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        switch (title, url) {
        case let (title?, url?): return "[\(title)](\(destination(url)))"
        case let (title?, nil): return title
        case let (nil, url?): return url
        case (nil, nil): return nil
        }
    }

    /// The selection's lines with every kind of line break as one, without the empty lines at either end.
    static func selectionLines(_ selection: String?) -> [String] {
        guard let selection else { return [] }
        var lines = lines(of: selection)
        while let first = lines.first, first.allSatisfy(\.isWhitespace) { lines.removeFirst() }
        while let last = lines.last, last.allSatisfy(\.isWhitespace) { lines.removeLast() }
        return lines
    }

    private static func lines(of text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .split(omittingEmptySubsequences: false, whereSeparator: { "\n\r\u{2028}\u{2029}".contains($0) })
            .map(String.init)
    }

    /// A title on several lines becomes one line: each line without its outer spaces, joined by one space.
    private static func oneLine(_ title: String) -> String {
        lines(of: title).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// `[` and `]` would end the link text early.
    private static func escaped(_ title: String) -> String {
        title.replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
    }

    /// A URL with a space or an unbalanced parenthesis would end the link early; Markdown takes it whole inside `<` and `>`.
    private static func destination(_ url: String) -> String {
        var depth = 0
        for character in url {
            if character.isWhitespace { return "<\(url)>" }
            if character == "(" { depth += 1 }
            if character == ")" { depth -= 1; if depth < 0 { return "<\(url)>" } }
        }
        return depth == 0 ? url : "<\(url)>"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
