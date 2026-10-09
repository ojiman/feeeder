import Foundation

/// Turns the model's raw text into something safe to show, or nil. The model's own words are never trusted as-is:
/// the spike saw names followed by 「」}」 and unrelated sentences, numbered lines, and statements instead of questions.
public enum SuggestionText {
    static let nameLength = 2...24
    static let questionLength = 10...80
    private static let leadingMarks = try! NSRegularExpression(pattern: #"^\s*(?:(?:テーマ名|名前|タイトル|問い)\s*[:：]\s*|(?:[-・•]+|\*+(?!\*)|\d+\s*[.)．]\s+|\d+\s*[、)）])\s*)"#)
    private static let wrappers: Set<Character> = ["「", "『", "【", "“", "\"", "'", "*"]
    private static let closers: Set<Character> = ["」", "』", "】", "”", "\"", "}", "{", "*"]

    /// A theme name: first line, marks removed, cut before any closing quote or brace, 2–24 characters.
    public static func name(from raw: String) -> String? {
        guard var text = firstLine(of: raw) else { return nil }
        text = String(text.drop(while: { wrappers.contains($0) }))
        if let cut = text.firstIndex(where: { closers.contains($0) }) { text = String(text[..<cut]) }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "。、．.,:：'")))
        guard nameLength.contains(text.count), !text.contains("{"), !text.contains("}") else { return nil }
        return text
    }

    /// A question: first line, marks and wrapping quotes removed, ends as a question, 10–80 characters.
    public static func question(from raw: String) -> String? {
        guard var text = firstLine(of: raw) else { return nil }
        text = unwrap(text).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix("か") { text += "。" }
        let endsAsQuestion = text.hasSuffix("か。") || text.hasSuffix("か？") || text.hasSuffix("？") || text.hasSuffix("?")
        guard endsAsQuestion, questionLength.contains(text.count), !text.contains("{"), !text.contains("}") else { return nil }
        return text
    }

    /// Removes one pair of quotes around the whole text. A fixed question that merely starts with 「テーマ名」 is left alone.
    private static func unwrap(_ text: String) -> String {
        let pairs: [Character: Character] = ["「": "」", "『": "』", "“": "”", "\"": "\"", "'": "'"]
        guard let first = text.first, let close = pairs[first], text.count >= 2, text.last == close else { return text }
        return String(text.dropFirst().dropLast())
    }

    private static func firstLine(of raw: String) -> String? {
        let visible = String(String.UnicodeScalarView(raw.unicodeScalars.filter { $0 == "\n" || $0 == "\r" || ($0.properties.generalCategory != .control && $0.properties.generalCategory != .format) }))
        guard var line = visible.split(whereSeparator: \.isNewline).map({ String($0).trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }) else { return nil }
        for _ in 0..<3 {
            let stripped = leadingMarks.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "").trimmingCharacters(in: .whitespaces)
            if stripped == line { break }
            line = stripped
        }
        return line.isEmpty ? nil : line
    }
}

public enum SuggestionPrompts {
    public static let maximumItems = 16
    public static let itemTextLimit = 120
    public static let nameTokenLimit = 32
    public static let questionTokenLimit = 90

    public struct Request: Sendable, Equatable {
        public let instructions: String
        public let prompt: String
        public let maximumTokens: Int
        public init(instructions: String, prompt: String, maximumTokens: Int) {
            self.instructions = instructions; self.prompt = prompt; self.maximumTokens = maximumTokens
        }
    }

    /// `items` are newest first; only the first `maximumItems` are used, each cut to `itemTextLimit` characters.
    public static func name(items: [SuggestionItem]) -> Request {
        Request(
            instructions: "あなたは読書ノートの整理を手伝います。記事のタイトル一覧に共通するテーマを、具体的な名詞句の名前（6〜14文字）にして日本語で1つだけ答えます。例: 「住宅ローン金利と家計の負担」「小型AIモデルの端末内推論」。名前だけを出力し、説明・記号・引用符は付けません。",
            prompt: "記事:\n" + list(items), maximumTokens: nameTokenLimit)
    }

    /// The fixed lens's own question is the template. `.custom` has none, so no request.
    public static func question(lens: QuestionLens, template: String, themeName: String, items: [SuggestionItem]) -> Request? {
        guard let angle = angle(for: lens) else { return nil }
        return Request(
            instructions: "あなたは読書ノートの整理を手伝います。『角度』に沿って、記事の内容に即した問いを日本語で1つだけ作ります。必ず「〜か。」「〜だろうか。」のような疑問文で終え、50文字以内にします。問いだけを出力し、番号・説明・引用符は付けません。記事にない事実は作りません。",
            prompt: "テーマ: \(themeName)\n角度: \(angle)\n定型の問い: \(template)\n記事:\n" + list(items), maximumTokens: questionTokenLimit)
    }

    static func angle(for lens: QuestionLens) -> String? {
        switch lens {
        case .assumption: "その主張が成り立つために暗黙に置いている前提を疑う"
        case .exception: "当てはまらない例外や、反対の立場からの反論を問う"
        case .condition: "どんな条件のもとで成り立ち、条件が変わると何が変わるかを問う"
        case .tradeoff: "得るものと引き換えに手放しているものを問う"
        case .personal: "読者自身の生活や仕事に当てはめるとどうかを問う"
        case .custom: nil
        }
    }

    private static func list(_ items: [SuggestionItem]) -> String {
        items.prefix(maximumItems).map { item in
            let flat = item.text.split(whereSeparator: \.isNewline).joined(separator: " ")
            return "- " + String(flat.prefix(itemTextLimit))
        }.joined(separator: "\n")
    }
}

/// A question proposal is only offered while the question is still the lens's untouched template.
public enum QuestionProposalEligibility {
    public static func isEligible(lens: QuestionLens, text: String, themeName: String) -> Bool {
        guard lens != .custom else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines) == lens.draft(themeName: themeName).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
