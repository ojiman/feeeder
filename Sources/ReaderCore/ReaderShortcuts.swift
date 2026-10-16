import Foundation

/// The keys of the reader, in one place (specification 3.1.5 and 3.7): the list's key handler takes its letters from here, and the
/// shortcut list in Settings shows these rows, so the list shows what the app does. Read only: keys cannot be changed.
public enum ReaderShortcuts {
    public enum Group: String, CaseIterable, Sendable {
        case reading = "読む", list = "一覧", original = "元ページ", note = "ノート"
    }

    public struct Row: Sendable, Equatable, Identifiable {
        public let group: Group
        /// The keys as the person presses them, for example ["j", "k"] or ["⌥⌘I"].
        public let keys: [String]
        public let action: String
        /// Where the keys do not work, or nil.
        public let limit: String?
        public var id: String { keys.joined(separator: " ") + action }
    }

    /// The single letters the reader handles without a modifier key, from the list or the article, when no text is being typed.
    public static let readingLetters: [String] = ["j", "k", "m", "s", "t", "b", "v", "n", "c", "/"]

    static let whileTyping = "文字の入力中は効きません"

    public static let rows: [Row] = [
        Row(group: .reading, keys: ["j", "k"], action: "次の記事・前の記事", limit: whileTyping),
        Row(group: .reading, keys: ["m"], action: "既読・未読を切り替える", limit: whileTyping),
        Row(group: .reading, keys: ["s"], action: "Starを付ける・外す", limit: whileTyping),
        Row(group: .reading, keys: ["t"], action: "記事を翻訳する・原文に戻す", limit: whileTyping),
        Row(group: .reading, keys: ["b"], action: "元ページをブラウザで開く", limit: whileTyping),
        Row(group: .list, keys: ["/"], action: "一覧をキーワードで絞り込む", limit: whileTyping),
        Row(group: .original, keys: ["v"], action: "元ページをアプリの中で開く", limit: whileTyping),
        Row(group: .original, keys: ["Esc"], action: "元ページを閉じて記事に戻る", limit: nil),
        Row(group: .original, keys: ["j", "k", "s", "n"], action: "元ページを開いたままでも使えます", limit: nil),
        Row(group: .note, keys: ["n", "⌥⌘I"], action: "ノートを開く・閉じる", limit: "n は文字の入力中は効きません"),
        Row(group: .note, keys: ["c"], action: "記事をノートに送る（記事で選んだ文は引用になります）", limit: whileTyping),
        Row(group: .note, keys: ["⌥⌘↑", "⌥⌘↓"], action: "ノートを開いたまま前・次の記事へ", limit: nil),
        Row(group: .note, keys: ["Esc"], action: "ノートを閉じて記事に戻る", limit: "日本語の変換中は、まず変換を取り消します"),
    ]

    public static func rows(in group: Group) -> [Row] { rows.filter { $0.group == group } }
}
