import Foundation
import Observation

/// One explicit send, bound to IDs rather than the reader's changing selection.
@Observable @MainActor public final class SummarySender {
    public struct Outcome: Equatable, Sendable {
        public let send: SendResult
        public let noteTitle: String
        public let aiMade: Bool
        public let message: String
        public let undoUntil: Date
    }
    public enum State: Equatable, Sendable { case idle, working, done(Outcome), failed(String), message(String) }
    public private(set) var state = State.idle
    private let store: ReaderStore
    private let assistant: (any TextGenerator)?
    private let isEnabled: @MainActor () -> Bool
    private let settings: @MainActor () -> SummarySettings
    private let deadline: Double
    private let now: () -> Date
    private var token = UUID()
    private var task: Task<Void, Never>?

    public init(store: ReaderStore, assistant: (any TextGenerator)?, isEnabled: @escaping @MainActor () -> Bool = { true },
                settings: @escaping @MainActor () -> SummarySettings = { SummarySettings.load() },
                deadline: Double = 20, now: @escaping () -> Date = { .now }) {
        self.store = store; self.assistant = assistant; self.isEnabled = isEnabled
        self.settings = settings; self.deadline = deadline; self.now = now
    }
    public var isWorking: Bool { state == .working }
    public var canUndo: Bool {
        if case .done(let outcome) = state { return now() < outcome.undoUntil }
        return false
    }

    @discardableResult public func start(articleID: UUID, noteID: UUID?) -> Bool {
        guard !isWorking else { return false }
        task?.cancel(); token = UUID()
        let mine = token
        state = .working
        do {
            try store.reloadIfNeeded()
            guard let article = store.article(id: articleID) else { throw NoteError.missingArticle }
            if let noteID, store.note(id: noteID) == nil { throw NoteError.missingNote }
            let title = article.title, url = article.originalURL
            let enabled = isEnabled(), options = settings()
            let content = try store.content(articleID: articleID, at: now())
            let input = content.flatMap { ArticleSummaryPrompt.make(title: title, text: $0.text, settings: options) }
            task = Task { [weak self] in
                guard let self else { return }
                var summary: String?
                if enabled, let assistant = self.assistant, let input {
                    do {
                        summary = try await withDeadline(self.deadline) {
                            guard await assistant.generationAvailability() == .available else { return nil }
                            let raw = try await assistant.generate(input.request)
                            return ArticleSummaryPrompt.clean(raw, format: options.format)
                        }
                    } catch { /* A model failure falls back to retained RSS text, never to an unmarked AI answer. */ }
                }
                guard self.token == mine, !Task.isCancelled else { return }
                guard !enabled || self.isEnabled() else { self.state = .message("AIをオフにしたため、送信を中止しました"); return }
                do {
                    // Recheck retention at the write, so an answer cannot revive expired content.
                    let current = try self.store.content(articleID: articleID, at: self.now())
                    if current == nil { summary = nil }
                    let aiMade = summary != nil
                    let fallback = current?.summary ?? ""
                    let block = NoteInsertion.summaryBlock(summary: summary ?? fallback, title: title, url: url, aiMade: aiMade)
                    let result = try self.store.sendArticle(articleID, to: noteID, block: block, newNoteTitle: title, at: self.now())
                    let noteTitle = self.store.note(id: result.noteID)?.title ?? NoteTitle.untitled
                    let sent = aiMade ? "要約を送りました" : (fallback.isEmpty ? "タイトルとURLだけ送りました" : "RSS要約と出典を送りました")
                    let reason = enabled && !aiMade ? "AIが使えないため、" : ""
                    self.state = .done(Outcome(send: result, noteTitle: noteTitle, aiMade: aiMade,
                        message: "「\(noteTitle)」に\(reason)\(sent)" + (aiMade && input?.wasCut == true ? "（本文の先頭3,000文字から要約）" : ""), undoUntil: self.now().addingTimeInterval(8)))
                } catch { self.state = .failed(error.localizedDescription) }
            }
        } catch { state = .failed(error.localizedDescription) }
        return true
    }
    public func cancel() {
        guard isWorking else { return }
        token = UUID(); task?.cancel(); task = nil; state = .message("送信を中止しました")
    }
    public func undo() {
        guard case .done(let outcome) = state else { return }
        guard now() < outcome.undoUntil else { state = .message("取り消しの時間が過ぎました。ノートを編集できます"); return }
        do {
            state = try store.undoSend(outcome.send, at: now()) ? .message("送信を取り消しました") : .message("ノートが変わったため、取り消せません")
        } catch { state = .failed(error.localizedDescription) }
    }
    public func dismiss() { if !isWorking { state = .idle } }
}
