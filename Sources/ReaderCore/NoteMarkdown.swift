import Foundation

public enum NoteMarkdown {
    public static func fileName(forTitle title: String) -> String {
        let forbidden = Set("/\\:".unicodeScalars)
        let safe = String(String.UnicodeScalarView(title.unicodeScalars.map {
            forbidden.contains($0) || $0.properties.generalCategory == .control ? " " : $0
        }))
        let folded = safe.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        let stem = String(folded.drop { $0 == "." || $0.isWhitespace })
        let hasName = stem.unicodeScalars.contains {
            guard $0 != "." && !CharacterSet.whitespacesAndNewlines.contains($0) else { return false }
            return switch $0.properties.generalCategory {
            case .control, .format, .nonspacingMark, .spacingMark, .enclosingMark: false
            default: true
            }
        }
        guard hasName else { return "ノート.md" }
        return String(stem.prefix(77)) + ".md"
    }

    public static func data(for text: String) -> Data { Data(text.utf8) }
}
