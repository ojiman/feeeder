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
    static let unfiledName = "未分類"

    /// `current` is the folder the subscription is in (empty: unfiled). It is never a candidate, since moving there changes nothing.
    public static func entries(query: String, folders: [String], current: String) -> [Entry] {
        let typed = SingleLineText.name(query)
        let others = folders.filter { !$0.isEmpty && $0 != current }
        if typed.isEmpty {
            return (current.isEmpty ? [] : [.unfiled]) + others.sorted().map(Entry.existing)
        }
        var result: [Entry] = []
        if typed == unfiledName {
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
}
