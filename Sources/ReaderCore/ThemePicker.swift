import Foundation

public struct ThemePickerRow: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case theme(UUID), create(String) }
    public let kind: Kind
    public let title: String
    public let included: Bool
    public init(kind: Kind, title: String, included: Bool) { self.kind = kind; self.title = title; self.included = included }
}

public enum ThemePickerAction: Equatable, Sendable { case toggle(UUID), create(String) }

/// Pure logic for the `t` picker: one text field filters the themes, ↑/↓ move a highlight and Return acts on it,
/// so adding to an existing theme works from the keyboard alone and typing an existing name never creates a duplicate.
public enum ThemePicker {
    public static func rows(themes: [(id: UUID, name: String)], memberOf: Set<UUID>, query: String) -> [ThemePickerRow] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = query.isEmpty ? themes : themes.filter { $0.name.localizedCaseInsensitiveContains(query) }
        var rows = matching.map { ThemePickerRow(kind: .theme($0.id), title: $0.name, included: memberOf.contains($0.id)) }
        if !query.isEmpty, !themes.contains(where: { $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame }) {
            rows.append(ThemePickerRow(kind: .create(query), title: "「\(query)」を新しいテーマとして作る", included: false))
        }
        return rows
    }

    /// An exact name wins; otherwise the first row, which is an existing theme whenever one matches.
    public static func defaultHighlight(rows: [ThemePickerRow], query: String) -> Int? {
        guard !rows.isEmpty else { return nil }
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty, let exact = rows.firstIndex(where: {
            if case .theme = $0.kind { return $0.title.localizedCaseInsensitiveCompare(query) == .orderedSame }
            return false
        }) { return exact }
        return 0
    }

    /// ⌘Return: create with the typed name even when other themes only partially match it; an exact name acts on that theme.
    public static func explicitAction(rows: [ThemePickerRow], query: String) -> ThemePickerAction? {
        if let create = rows.first(where: { if case .create = $0.kind { true } else { false } }), case .create(let name) = create.kind {
            return .create(name)
        }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return action(rows: rows, highlighted: defaultHighlight(rows: rows, query: query))
    }

    public static func move(_ index: Int?, by delta: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let index else { return delta >= 0 ? 0 : count - 1 }
        return min(max(0, index + delta), count - 1)
    }

    public static func action(rows: [ThemePickerRow], highlighted: Int?) -> ThemePickerAction? {
        guard let highlighted, rows.indices.contains(highlighted) else { return nil }
        switch rows[highlighted].kind {
        case .theme(let id): return .toggle(id)
        case .create(let name): return .create(name)
        }
    }
}
