import Foundation
import Observation

/// A piece of text the assistant may look at: an article's title and, while it is still held, its RSS summary.
public struct SuggestionItem: Sendable, Equatable {
    public let id: UUID
    public let text: String
    public init(id: UUID, text: String) { self.id = id; self.text = text }
}

public struct ThemeCandidateInput: Sendable, Equatable {
    public let themeID: UUID
    public let members: [SuggestionItem]
    public init(themeID: UUID, members: [SuggestionItem]) { self.themeID = themeID; self.members = members }
}

public enum AssistantAvailability: Sendable, Equatable { case available, assetsMissing, unsupported }

/// The on-device assistant behind a protocol so tests never touch a real model. Implementations must not use the
/// network and must not request system assets (decision 0009). They run off the main actor.
public protocol ThemeAssistant: Sendable {
    func availability() async -> AssistantAvailability
    func nearestThemes(for item: SuggestionItem, candidates: [ThemeCandidateInput], background: [SuggestionItem]) async throws -> [ThemeMatch]
    func clusters(of items: [SuggestionItem], background: [SuggestionItem]) async throws -> [[UUID]]
}

/// Asks the assistant for suggestions and hands the screen only answers that are still current: a request ID
/// is checked when the answer arrives, and the enable switch is read again at that moment.
@Observable @MainActor public final class ThemeSuggestionModel {
    public struct Clusters: Equatable, Sendable {
        public var groups: [[UUID]]
        public var usedCount: Int
        public var totalCount: Int
        public static let empty = Clusters(groups: [], usedCount: 0, totalCount: 0)
    }

    public private(set) var nearestArticleID: UUID?
    public private(set) var nearestThemes: [ThemeMatch] = []
    public private(set) var clusters = Clusters.empty
    public private(set) var isFindingClusters = false
    public private(set) var availability: AssistantAvailability?

    private let store: ReaderStore
    private let assistant: (any ThemeAssistant)?
    private let isEnabled: @MainActor () -> Bool
    private let now: () -> Date
    private var nearestToken = UUID()
    private var clusterToken = UUID()

    public init(store: ReaderStore, assistant: (any ThemeAssistant)?, isEnabled: @escaping @MainActor () -> Bool = { true },
                now: @escaping () -> Date = { .now }) {
        self.store = store; self.assistant = assistant; self.isEnabled = isEnabled; self.now = now
    }

    /// Reads the system's state only while the setting is on; "off" is the setting's own answer.
    public func refreshAvailability() async {
        guard isEnabled() else { availability = nil; return }
        guard let assistant else { availability = .unsupported; return }
        let value = await assistant.availability()
        availability = isEnabled() ? value : nil
    }

    public func invalidate() {
        nearestToken = UUID(); nearestThemes = []; nearestArticleID = nil
        invalidateClusters()
    }
    public func invalidateClusters() {
        clusterToken = UUID(); clusters = .empty; isFindingClusters = false
    }

    public func loadNearest(for articleID: UUID) async {
        let token = UUID(); nearestToken = token
        nearestArticleID = articleID; nearestThemes = []
        guard isEnabled(), let assistant, let item = suggestionItem(for: articleID) else { return }
        let candidates = candidateInputs(excluding: articleID)
        guard !candidates.isEmpty else { return }
        let used = Set([articleID] + candidates.flatMap { $0.members.map(\.id) })
        let background = backgroundItems(excluding: used)
        do {
            let matches = try await assistant.nearestThemes(for: item, candidates: candidates, background: background)
            guard token == nearestToken, !Task.isCancelled, isEnabled() else { return }
            nearestThemes = matches.filter { store.theme(id: $0.themeID) != nil }
        } catch { /* No suggestion. The manual picker is unaffected. */ }
    }

    public func loadClusters() async {
        let token = UUID(); clusterToken = token
        guard isEnabled(), let assistant else { clusters = .empty; isFindingClusters = false; return }
        let all = store.unfiledStarredArticleIDs(keeping: nil)
        guard all.count >= SuggestionTuning.minimumItemsToCluster else { clusters = .empty; isFindingClusters = false; return }
        let items = all.prefix(SuggestionTuning.maximumClusterItems).compactMap { self.suggestionItem(for: $0) }
        guard items.count >= SuggestionTuning.minimumItemsToCluster else { clusters = .empty; isFindingClusters = false; return }
        let background = backgroundItems(excluding: Set(items.map(\.id)))
        isFindingClusters = true
        defer { if token == clusterToken { isFindingClusters = false } }
        do {
            let groups = try await assistant.clusters(of: items, background: background)
            guard token == clusterToken, !Task.isCancelled, isEnabled() else { return }
            let stillUnfiled = Set(store.unfiledStarredArticleIDs(keeping: nil))
            let cleaned = groups.map { $0.filter { stillUnfiled.contains($0) } }
                .filter { $0.count >= SuggestionTuning.minimumClusterSize }
            clusters = Clusters(groups: Array(cleaned.prefix(SuggestionTuning.maximumClusters)), usedCount: items.count, totalCount: all.count)
        } catch {
            if token == clusterToken { clusters = .empty }
        }
    }

    // MARK: Inputs. Only held content and the themes' own records are used; expired text never comes back.

    private func suggestionItem(for articleID: UUID) -> SuggestionItem? {
        guard let article = store.article(id: articleID) else { return nil }
        let summary = store.isContentAvailable(article, at: now()) ? article.summary : ""
        return Self.item(id: articleID, title: article.title, summary: summary)
    }
    private func candidateInputs(excluding articleID: UUID) -> [ThemeCandidateInput] {
        store.themes.compactMap { theme in
            let links = store.themeArticles.filter { $0.themeID == theme.id && $0.articleID != articleID }
                .sorted { $0.addedAt != $1.addedAt ? $0.addedAt > $1.addedAt : $0.key < $1.key }
                .prefix(SuggestionTuning.maximumMembersPerTheme)
            let members = links.compactMap { Self.item(id: $0.articleID, title: $0.title, summary: $0.summary) }
            return members.isEmpty ? nil : ThemeCandidateInput(themeID: theme.id, members: members)
        }
    }
    /// The newest articles of the whole library, used only to give the centering step a steadier average.
    private func backgroundItems(excluding used: Set<UUID>) -> [SuggestionItem] {
        store.articles.lazy.filter { !used.contains($0.id) }.compactMap { self.suggestionItem(for: $0.id) }
            .prefix(SuggestionTuning.backgroundItems).map { $0 }
    }
    private static func item(id: UUID, title: String, summary: String) -> SuggestionItem? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = summary.isEmpty ? title : title + "\n" + summary
        guard !text.isEmpty else { return nil }
        return SuggestionItem(id: id, text: String(text.prefix(SuggestionTuning.textCharacterLimit)))
    }
}
