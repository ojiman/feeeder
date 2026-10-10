import Foundation
import Observation

/// Asks the on-device model for one of the note actions, only when the person asks, and gives back a card only while it still
/// matches the note and the selection it was made for. It never writes: adopting is the caller's edit (decision 0009).
@Observable @MainActor public final class NoteActionModel {
    public struct Card: Equatable, Sendable {
        public let action: NoteAction
        public let target: NoteTarget
        /// The note and the selection the card was made for; adopting is allowed only while both are unchanged.
        public let noteText: String
        public let selection: NSRange
        public let answer: String
        public let wasCut: Bool
    }
    public enum Reason: Equatable, Sendable { case disabled, unsupported, assetsMissing, noText, tooLong }
    public enum State: Equatable, Sendable {
        case idle, working(NoteAction), ready(Card), unavailable(Reason), failed
    }

    public private(set) var state = State.idle
    private let assistant: (any ThemeAssistant)?
    private let isEnabled: @MainActor () -> Bool
    private let deadline: Double
    private var token = UUID()
    private var task: Task<Void, Never>?
    private var pending: (note: String, selection: NSRange)?

    public init(assistant: (any ThemeAssistant)?, isEnabled: @escaping @MainActor () -> Bool = { true }, deadline: Double = 20) {
        self.assistant = assistant; self.isEnabled = isEnabled; self.deadline = deadline
    }

    public func request(_ action: NoteAction, note: String, selection: NSRange, goal: String) {
        supersede()
        let mine = token
        guard isEnabled() else { state = .unavailable(.disabled); return }
        guard let assistant else { state = .unavailable(.unsupported); return }
        guard let target = NoteSection.target(in: note, selection: selection) else { state = .unavailable(.noText); return }
        let made: SuggestionPrompts.Request, wasCut: Bool
        switch NoteActionPrompt.make(action, text: target.text, goal: goal) {
        case .noText: state = .unavailable(.noText); return
        case .tooLong: state = .unavailable(.tooLong); return
        case .request(let request, let cut): made = request; wasCut = cut
        }
        state = .working(action)
        pending = (note, selection)
        task = Task { [weak self] in
            let availability = await assistant.generationAvailability()
            guard let self, self.token == mine, !Task.isCancelled else { return }
            guard self.isEnabled() else { self.state = .unavailable(.disabled); return }
            switch availability {
            case .available: break
            case .assetsMissing: self.state = .unavailable(.assetsMissing); return
            case .unsupported: self.state = .unavailable(.unsupported); return
            }
            do {
                let raw = try await withDeadline(self.deadline) { try await assistant.generate(made) }
                guard self.token == mine, !Task.isCancelled else { return }
                guard self.isEnabled() else { self.state = .unavailable(.disabled); return }
                if let answer = NoteActionPrompt.clean(raw, for: action) {
                    self.state = .ready(Card(action: action, target: target, noteText: note, selection: selection, answer: answer, wasCut: wasCut))
                } else { self.state = .failed }
            } catch {
                if self.token == mine { self.state = .failed }
            }
        }
    }

    /// Call whenever the note text or the selection changes. A request that is running and a card that was made for something else
    /// are dropped.
    public func noteDidChange(note: String, selection: NSRange) {
        switch state {
        case .working:
            if let pending, pending.note == note, pending.selection == selection { return }
            reset()
        case .ready(let card):
            if card.noteText != note || card.selection != selection { reset() }
        default: break
        }
    }

    /// The card, only if it was made for exactly this note and selection. Adopting must use this, never `state` alone.
    public func currentCard(note: String, selection: NSRange) -> Card? {
        if case .ready(let card) = state, card.noteText == note, card.selection == selection { return card }
        return nil
    }

    public func cancel() {
        guard case .working = state else { return }
        reset()
    }

    public func reset() {
        supersede(); state = .idle
    }

    private func supersede() {
        task?.cancel(); task = nil; token = UUID(); pending = nil
    }
}
