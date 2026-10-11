import Foundation
import Observation

/// A feed that was fetched and read, ready to be added without asking the network again.
public struct CheckedFeed: Sendable, Equatable, Identifiable {
    public let id = UUID()
    public let parsed: ParsedFeed
    public let etag: String?
    public let lastModified: String?
    /// False for pasted XML: there is no response to remember.
    public let fetched: Bool
    public init(parsed: ParsedFeed, etag: String?, lastModified: String?, fetched: Bool) {
        self.parsed = parsed; self.etag = etag; self.lastModified = lastModified; self.fetched = fetched
    }
    public static func == (lhs: CheckedFeed, rhs: CheckedFeed) -> Bool { lhs.id == rhs.id }
}

/// Checks the address in the add-subscription sheet while the person types (decision 0036).
/// Each edit drops the old result at once and cancels the old check; a late answer for an old edit is never shown.
@Observable @MainActor public final class FeedChecker {
    public enum State: Equatable {
        case idle, checking
        case ready(CheckedFeed)
        case failed(String)

        public var onReturn: ReturnAction {
            switch self {
            case .ready(let feed): .add(feed)
            case .checking: .waitForAnswer
            case .idle, .failed: .checkAgain               // a failure may have been a bad moment: try once more
            }
        }
        public var whileWaitingForReturn: WaitingAction {
            switch self {
            case .ready(let feed): .add(feed)
            case .failed: .giveUp
            case .idle, .checking: .keepWaiting
            }
        }
    }
    /// What pressing Return means in a state.
    public enum ReturnAction: Equatable { case add(CheckedFeed), waitForAnswer, checkAgain }
    /// What an answer means to a person who already pressed Return and is waiting.
    public enum WaitingAction: Equatable { case add(CheckedFeed), keepWaiting, giveUp }
    public private(set) var state = State.idle
    private let fetch: @Sendable (FeedCheckRequest) async throws -> CheckedFeed
    private let sleep: @Sendable (Duration) async throws -> Void
    private var task: Task<Void, Never>?
    private var generation = 0

    public init(fetch: @escaping @Sendable (FeedCheckRequest) async throws -> CheckedFeed = { try await FeedChecker.fetch($0) },
                sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.fetch = fetch; self.sleep = sleep
    }

    /// Call on every edit. `delay` is how long to wait for the person to pause (see `FeedCheckRequest.delay`).
    /// `asked` is true when the person pressed Return: text that is not an address yet then gets an answer, not silence.
    public func update(source: String, xml: String = "", manual: Bool = false, delay: Duration, asked: Bool = false) {
        task?.cancel()
        generation += 1
        state = .idle
        let mine = generation
        let request = FeedCheckRequest.make(source: source, xml: xml, manual: manual, asked: asked)
        var hint: String?
        if request == nil {
            hint = asked && manual && ArticleURL.validated(source) != nil ? "XMLを入れてください。" : FeedCheckRequest.hint(source: source, asked: asked)
        }
        guard request != nil || hint != nil else { return }
        task = Task { [fetch, sleep] in
            do {
                if delay > .zero { try await sleep(delay) }
                guard mine == generation else { return }
                guard let request else { state = .failed(hint ?? ""); return }
                state = .checking
                let feed = try await fetch(request)
                guard mine == generation, !Task.isCancelled else { return }
                state = .ready(feed)
            } catch {
                guard mine == generation, !Task.isCancelled, !(error is CancellationError) else { return }
                state = .failed(FeedCheckMessage.text(for: error, pastedXML: manual))
            }
        }
    }

    /// Stops a check that is running and forgets the result (the sheet is closing).
    public func cancel() { task?.cancel(); generation += 1; state = .idle }

    /// Fetches (or parses) the request and reads it as a feed. The checks of the parser (size, HTML, entities) apply.
    public nonisolated static func fetch(_ request: FeedCheckRequest, client: FeedClient = FeedClient()) async throws -> CheckedFeed {
        switch request {
        case .url(let url):
            guard case .modified(let parsed, let etag, let modified) = try await client.fetch(url: url) else { throw HTTPError.invalidResponse }
            return CheckedFeed(parsed: parsed, etag: etag, lastModified: modified, fetched: true)
        case .xml(let data, let url):
            let parsed = try await Task.detached(priority: .userInitiated) { try FeedParser.parse(data, sourceURL: url) }.value
            return CheckedFeed(parsed: parsed, etag: nil, lastModified: nil, fetched: false)
        }
    }
}
