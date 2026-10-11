import Foundation

/// The request for a summary of one article, with a fixed input budget (decisions 0013 and 0015): the body is cut to its first
/// `bodyLimit` characters (about 2,200 tokens at the measured 0.74 tokens per character), so instructions, title, body and
/// the capped output stay well inside the model's 4,096 tokens.
public enum ArticleSummaryPrompt {
    public static let bodyLimit = 3_000
    public static let outputTokenLimit = 400
    public static let titleLimit = 200
    public static let instructions = "あなたは読書ノートの整理を手伝います。与えられた記事を、日本語で3文以内に要約します。記事に書かれていることだけを使い、記事にない事実や評価を足しません。「〜という見方がある」のような留保や、否定・条件は、強めたり逆にしたりしません。数字はそのまま使います。要約の文章だけを出力し、見出し・箇条書き・番号・引用符・前置きは付けません。"

    public struct Input: Sendable, Equatable {
        public let request: TextRequest
        public let wasCut: Bool
    }

    /// nil when there is no text to summarize.
    public static func make(title: String, text: String, settings: SummarySettings = SummarySettings()) -> Input? {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        let used = String(body.prefix(bodyLimit))          // by Character: never splits an emoji or a combining mark
        let heading = title.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        var rules = instructions.replacingOccurrences(of: "3文以内", with: "\(settings.length.rawValue)文以内")
        if settings.format == .bullets {
            rules = rules.replacingOccurrences(of: "要約の文章だけを出力し、見出し・箇条書き・番号・引用符・前置きは付けません。", with: "各項目を - で始める箇条書きの行だけを出力します。見出しや前置きは付けません。")
        }
        if !settings.extraInstruction.isEmpty { rules += "\n追加の指示（本人の言葉: \(settings.extraInstruction)）。固定の規則を優先します。" }
        let request = TextRequest(instructions: rules, prompt: "タイトル: \(String(heading.prefix(titleLimit)))\n本文:\n\(used)", maximumTokens: outputTokenLimit)
        return Input(request: request, wasCut: body.count > bodyLimit)
    }

    /// The model's answer made safe to show: invisible control characters removed, wrapping quotes taken off, blank lines folded,
    /// at most 1,200 characters. nil when nothing is left.
    public static func clean(_ raw: String, format: SummaryFormat = .prose) -> String? {
        let visible = String(String.UnicodeScalarView(raw.unicodeScalars.filter {
            $0 == "\n" || $0.value == 0x200D || ($0.properties.generalCategory != .control && $0.properties.generalCategory != .format)
        }))
        var text = visible.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
        let pairs: [Character: Character] = ["「": "」", "『": "』", "“": "”", "\"": "\""]
        if let first = text.first, let close = pairs[first], text.count >= 2, text.last == close, !text.dropFirst().dropLast().contains(close) {
            text = String(text.dropFirst().dropLast())
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if format == .bullets {
            text = text.components(separatedBy: .newlines).compactMap { line in
                let item = line.replacingOccurrences(of: "^\\s*(?:[-*•]\\s*|[0-9]+[.)]\\s*)", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                return item.isEmpty ? nil : "- " + item
            }.joined(separator: "\n")
        }
        return String(text.prefix(1_200))
    }
}
