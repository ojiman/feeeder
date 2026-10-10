import Foundation

public enum NoteAction: Sendable, Equatable { case clearer, essence }

/// The requests for the two note actions, with a fixed input budget (decisions 0013 and 0016): at most 1,300 characters of the
/// person's text (about 1,000 tokens at 0.74 tokens per character), the goal only for the essence, short fixed instructions.
public enum NoteActionPrompt {
    public static let textLimit = 1_300
    /// A rewrite is about as long as its input (up to 1,300 characters, ~1,000 tokens), so its cap leaves room; the model's
    /// 4,096 tokens stay far from full (about 220 for the instructions + 1,000 + 1,200).
    public static let clearerOutputTokens = 1_200
    public static let essenceOutputTokens = 300

    public static let clearerInstructions = "あなたは文章の推敲を手伝います。与えられた文章を、意味を変えずに、読みやすい日本語に書き直します。事実・数字・否定・留保（「分からない」「かもしれない」などの不確かさ）は変えず、強めも弱めもしません。一人称と文章の言語はそのままにし、新しい情報を足しません。書き直した文章だけを出力し、前置き・説明・引用符は付けません。"
    public static let essenceInstructions = "あなたは読書ノートの整理を手伝います。与えられた文章の要点を、日本語の短い3行にまとめます。各行は1文で、書かれていることだけを使い、不確かさの表現は保ちます。学習ゴールが示されていれば、それに関わる点を優先します。3行だけを出力し、見出し・前置き・説明は付けません。"

    public enum Outcome: Equatable, Sendable {
        case request(SuggestionPrompts.Request, wasCut: Bool)
        case tooLong          // clearer only: it must not rewrite part of a text
        case noText
    }

    public static func make(_ action: NoteAction, text: String, goal: String) -> Outcome {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .noText }
        switch action {
        case .clearer:
            guard text.count <= textLimit else { return .tooLong }
            return .request(.init(instructions: clearerInstructions, prompt: "文章:\n\(text)", maximumTokens: clearerOutputTokens), wasCut: false)
        case .essence:
            let used = String(text.prefix(textLimit))                       // by Character: never splits an emoji or a combining mark
            let aim = goal.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
            let prompt = (aim.isEmpty ? "" : "学習ゴール: \(aim)\n") + "文章:\n\(used)"
            return .request(.init(instructions: essenceInstructions, prompt: prompt, maximumTokens: essenceOutputTokens), wasCut: text.count > textLimit)
        }
    }

    /// clearer: the rewrite with invisible characters removed (not the zero width joiner), trimmed, one pair of wrapping quotes taken off.
    /// essence: at most three lines, list marks removed, each shown as `・…`.
    public static func clean(_ raw: String, for action: NoteAction) -> String? {
        let visible = String(String.UnicodeScalarView(raw.unicodeScalars.filter {
            $0 == "\n" || $0 == "\r" || $0.value == 0x200D || ($0.properties.generalCategory != .control && $0.properties.generalCategory != .format)
        }))
        switch action {
        case .clearer:
            var text = visible.trimmingCharacters(in: .whitespacesAndNewlines)
            let pairs: [Character: Character] = ["「": "」", "『": "』", "“": "”", "\"": "\""]
            if let first = text.first, let close = pairs[first], text.count >= 2, text.last == close, !text.dropFirst().dropLast().contains(close) {
                text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return text.isEmpty ? nil : text
        case .essence:
            let lines = visible.components(separatedBy: .newlines).compactMap { line -> String? in
                var text = line.trimmingCharacters(in: .whitespaces)
                text = text.replacingOccurrences(of: #"^(?:[-・•*]+|\d+\s*[.)．）、])\s*"#, with: "", options: .regularExpression)
                return text.isEmpty ? nil : text
            }
            guard !lines.isEmpty else { return nil }
            return lines.prefix(3).map { "・" + $0 }.joined(separator: "\n")
        }
    }
}
