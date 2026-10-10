import Foundation
import Observation

/// Asks the on-device model for a summary of one article, only when the person asks. It writes nothing: not the note, not the
/// store. An answer is shown only if it is still the current request and the Settings switch is still on (decision 0009).
@Observable @MainActor public final class ArticleSummaryModel {
    public struct Summary: Equatable, Sendable {
        public let articleID: UUID
        public let text: String
        /// The body was longer than the budget and only its start was used.
        public let wasCut: Bool
        /// The article's own text was gone; the RSS summary that the theme recorded was used.
        public let fromThemeSummary: Bool
    }
    public enum Reason: Equatable, Sendable { case disabled, noText, unsupported, assetsMissing }
    public enum State: Equatable, Sendable {
        case idle, working, ready(Summary), unavailable(Reason), failed
    }

    public private(set) var state = State.idle
    private let store: ReaderStore
    private let assistant: (any TextGenerator)?
    private let isEnabled: @MainActor () -> Bool
    private let deadline: Double
    private let now: () -> Date
    private var token = UUID()
    private var task: Task<Void, Never>?

    public init(store: ReaderStore, assistant: (any TextGenerator)?, isEnabled: @escaping @MainActor () -> Bool = { true },
                deadline: Double = 20, now: @escaping () -> Date = { .now }) {
        self.store = store; self.assistant = assistant; self.isEnabled = isEnabled; self.deadline = deadline; self.now = now
    }

    /// Starts one request for the article; a request that is still running is replaced and its answer is dropped.
    public func request(articleID: UUID, themeID: UUID?) {
        supersede()
        let mine = token
        guard isEnabled() else { state = .unavailable(.disabled); return }
        guard let assistant else { state = .unavailable(.unsupported); return }
        guard let source = source(for: articleID, themeID: themeID),
              let input = ArticleSummaryPrompt.make(title: store.article(id: articleID)?.title ?? "", text: source.text) else {
            state = .unavailable(.noText); return
        }
        state = .working
        task = Task { [weak self] in
            let availability = await assistant.generationAvailability()
            guard let self, self.token == mine, !Task.isCancelled else { return }
            guard self.isEnabled() else { self.state = .unavailable(.disabled); return }
            switch availability {
            case .available: break
            case .assetsMissing: self.state = .unavailable(.assetsMissing); return
            case .unsupported: self.state = .unavailable(.unsupported); return
            }
            let request = input.request
            do {
                let raw = try await withDeadline(self.deadline) { try await assistant.generate(request) }
                guard self.token == mine, !Task.isCancelled else { return }
                guard self.isEnabled() else { self.state = .unavailable(.disabled); return }
                if let text = ArticleSummaryPrompt.clean(raw) {
                    self.state = .ready(Summary(articleID: articleID, text: text, wasCut: input.wasCut, fromThemeSummary: source.fromThemeSummary))
                } else { self.state = .failed }
            } catch {
                if self.token == mine { self.state = .failed }
            }
        }
    }

    /// Stops a running request and drops its answer.
    public func cancel() {
        guard state == .working else { return }
        supersede(); state = .idle
    }

    /// Back to nothing: the article changed or the person left the summary.
    public func reset() {
        supersede(); state = .idle
    }

    private func supersede() {
        task?.cancel(); task = nil; token = UUID()
    }

    /// The article's own retained text first; if it is gone, the RSS summary the theme recorded (only for a member article).
    private func source(for articleID: UUID, themeID: UUID?) -> (text: String, fromThemeSummary: Bool)? {
        if let content = try? store.content(articleID: articleID, at: now()), !content.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (content.text, false)
        }
        if let themeID, let link = store.themeArticles.first(where: { $0.themeID == themeID && $0.articleID == articleID }),
           !link.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (link.summary, true)
        }
        return nil
    }
}
