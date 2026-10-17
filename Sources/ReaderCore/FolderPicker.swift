import Foundation

/// The candidates of 「フォルダへ移動…」: the person types, the existing folders narrow down, and a name that is not a folder yet can be
/// made and moved to in the same step.
public enum FolderPicker {
    public enum Entry: Equatable, Sendable {
        case unfiled
        case existing(String)
        case create(String)
        /// The folder the subscription goes to (empty: unfiled).
        public var folder: String {
            switch self { case .unfiled: ""; case .existing(let name), .create(let name): name }
        }
    }
    static let unfiledName = String(localized: "Unfiled", bundle: ReaderLocalization.bundle)

    /// `current` is the folder the subscription is in (empty: unfiled). It is never a candidate, since moving there changes nothing.
    public static func entries(query: String, folders: [String], current: String) -> [Entry] {
        let typed = SingleLineText.name(query)
        let others = folders.filter { !$0.isEmpty && $0 != current }
        if typed.isEmpty {
            return (current.isEmpty ? [] : [.unfiled]) + others.sorted().map(Entry.existing)
        }
        var result: [Entry] = []
        if typed == unfiledName {
            // A folder named in another UI language is still the person's data.
            if folders.contains(typed) { return typed == current ? [] : [.existing(typed)] }
            return current.isEmpty ? [] : [.unfiled]
        }
        if !current.isEmpty, unfiledName.localizedStandardContains(typed) { result.append(.unfiled) }
        let matches = others.filter { $0.localizedStandardContains(typed) }
            .sorted { a, b in
                let pa = a.lowercased().hasPrefix(typed.lowercased()), pb = b.lowercased().hasPrefix(typed.lowercased())
                return pa != pb ? pa : a < b
            }
        result += matches.map(Entry.existing)
        if !folders.contains(typed) { result.append(.create(typed)) }
        return result
    }

    // MARK: Choosing at registration

    public enum Step: Sendable { case up, down }

    /// Nothing is highlighted until a name is typed, so Return on an untouched chooser adds the subscription as unfiled.
    /// Once a name is typed, the best match is highlighted, so typing a name and pressing Return goes there.
    public static func highlight(afterTyping query: String, entries: [Entry]) -> Int? {
        SingleLineText.name(query).isEmpty || entries.isEmpty ? nil : 0
    }

    /// ↑ and ↓. The highlight stops at the last candidate; ↑ from the first returns to "no folder" while nothing is typed.
    public static func highlight(from current: Int?, step: Step, count: Int, query: String) -> Int? {
        guard count > 0 else { return nil }
        switch step {
        case .down: return min(count - 1, (current ?? -1) + 1)
        case .up:
            guard let current else { return nil }
            if current > 0 { return min(current - 1, count - 1) }
            return SingleLineText.name(query).isEmpty ? nil : 0
        }
    }

    /// The folder a highlighted candidate stands for; no highlight (or a stale one) means unfiled.
    public static func destination(highlighted: Int?, in entries: [Entry]) -> String {
        guard let highlighted, entries.indices.contains(highlighted) else { return "" }
        return entries[highlighted].folder
    }
}
