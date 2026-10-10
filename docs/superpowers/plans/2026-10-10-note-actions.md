# N5: Note actions — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This project keeps one supervised implementer ([decision 0002](../../decisions/0002-single-supervised-writer.md)).

**Goal:** Below the note, two one-step AI actions help the person with the part of the note they are working on: 「わかりやすく」 (make it clearer) and 「3行の要点」 (the essence in three lines). Each makes one card; the person adopts it or not; adopting is one undo step.

**Architecture:** A pure `NoteSection` finds the text the action works on (the selection, or the section under the cursor). A pure `NoteActionPrompt` builds the request within a fixed budget and cleans the answer. An `@MainActor` `NoteActionModel` (the same shape as `ArticleSummaryModel`) asks `ThemeAssistant.generate`, and drops its card when the note or the selection changes. A small AppKit bridge (`NoteTextHandle`) finds the note's `NSTextView` so that an adopt is a real edit of the text view, which gives ⌘Z; N4's adopt moves onto the same path. The buttons use the borderless style, because borderless SwiftUI buttons are AppKit buttons and can be pressed in a test (the N4 card's buttons could not).

**Tech Stack:** Swift 6, SwiftUI, AppKit (`NSTextView`, `NSUndoManager`), FoundationModels through the existing generator, Swift Testing. No new dependency, no API above the macOS 26.6 build floor.

**Spec:** [decision 0013](../../decisions/0013-goal-and-note-for-themes.md) (points 5 and 6), [decision 0015](../../decisions/0015-article-summary-details.md), [roadmap Part 1c, row N5](2026-10-10-theme-notes.md), [the experiment](../../verification/2026-10-10-note-ai-experiment.md). Merging this plan approves it. Plan approval is not product acceptance.

**Language:** New project text is in English (AGENTS.md, "Language"). App labels stay Japanese; they are quoted as they appear, with a short English gloss.

## Decisions for you (merging approves them)

1. **Two actions, not four.** The experiment found that "what is missing for the goal" and "an opposing view" mostly repeat the article and do not argue with the note, while rewriting and the three-line essence work. So N5 builds only 「わかりやすく」 and 「3行の要点」. The other two are not built; if you want them, the Claude hand-off (N6) is the place, because a stronger model reads the note there.
2. **Where.** A bar of two buttons at the bottom of the note column (note face only). A card appears just above the bar while there is an answer, working state, or a message. If on-device AI is off in Settings, the bar is **not shown** and nothing is called. If it is on but the model is unavailable, the buttons are shown disabled and a line says why (the app never downloads the model). The articles face has no bar.
3. **What an action works on.** If you have selected text: the selection. Otherwise the **section under the cursor**: from the nearest line that starts with `#` at or above the cursor (the text before the first heading counts as a section) to the line before the next `#` line. When a section has a heading, the heading is kept and only the text under it is used. A blank section or selection: the buttons are disabled with 「書き直す文章がありません」.
4. **Budget.** The text is at most **1,300 characters** (about 1,000 tokens at 0.74 tokens per character, decision 0013). 「わかりやすく」 **refuses** a longer text with 「長すぎます。選択範囲を短くしてください」 (it must not rewrite half a section); 「3行の要点」 uses the first 1,300 characters and the card says so. The goal (at most 200 characters) is added only to 「3行の要点」; 「わかりやすく」 does not get it, so the rewrite does not drift toward the goal. Instructions stay under 300 characters, the output is capped at 700 tokens, and the deadline is 20 seconds, as in N4.
5. **What adopting does.** 「わかりやすく」: **replaces** the selection or the section's text (not its heading) with the rewrite. 「3行の要点」: **inserts** three lines, each starting with 「・」, as a new paragraph right after the section or selection (the same insertion rules as N4). The card has 「採用」 (Adopt), 「別の案」 (Another take), and 「閉じる」 (Close). Nothing reaches the note except by 「採用」; the card says 「AIによる案です。誤りを含むことがあります。」 and, for a rewrite, 「元の文章は ⌘Z で戻せます」 (Undo restores the original text).
6. **Undo (the native bridge).** Adopting is done as an edit of the note's own text view (`shouldChangeText` / `replaceCharacters` / `didChangeText`), so it is **one ⌘Z step**, and the editor's save-as-you-type path stores the result. The bridge is small: it finds the `NSTextView` that belongs to the note editor and exposes the current selection and the edit. N4's adopt uses it too (a summary becomes undoable). If the text view cannot be found (it is not mounted), the adopt falls back to the existing save path without undo, and the card says so. The bridge is also the first step of PR 10 (editor scale); N5 does not add scale.
7. **A card is dropped when it could be wrong.** When the note's text changes or the selection moves after the card was made, the card is removed and cannot be adopted (it says nothing; a removed card is the signal). Switching theme or face, going to another article's summary view, or turning AI off also drops it. A late answer is never shown.
8. **Not in this PR.** The two actions that were left out (decision 1), a chat, actions on several sections at once, translation, using the Writing Tools of the system instead of our own action (still an open item), a cache of answers, and the removal of the unreachable question code (N2b).

## Global Constraints

- Support floor macOS 27.0; build floor and CI stay macOS 26.6 / Swift 6.3.3. No macOS 27-only API (character limits, not `tokenCount(for:)`). No method references as `Binding` setters; no mutated captured `var` in `@MainActor` closures in tests.
- Decision 0009: no network, no automatic asset download, nothing written to the note except by the adopt action, the Settings switch is read when asking and when the answer arrives, prompts are not logged.
- A text edit never changes text outside the range it replaces; the person's text before and after is byte for byte the same (verify with strings that contain CRLF, emoji and combining marks). A failed save of an adopt is shown and never reported as success.
- Tests use synthetic text and a fake assistant only. One theme per PR. Failing tests first. Commit and PR text in English. Add the attribution line the session gives. Do not push to `main`, sign, or release. After implementation and one independent review of a fixed commit, push the branch and open the PR without asking.
- UI tests: a UI test that suspends with `Task.sleep` after creating windows can stop the whole test process silently (see [the N4 record](../../verification/2026-10-10-ai-summary.md)). Wait by pumping the run loop (`pumpRunLoop`), put new UI tests in a suite of their own, run each alone, and say which ran how. Anything that needs the main actor to make progress is tested below the view.

## Review Focus

1. A selection or section that contains CRLF, emoji, combining marks, `#` inside a line, a heading with no body, a note with no heading, a cursor at the very start or very end → Task 1.
2. The replace must touch only the intended range, and the ranges (UTF-16 in the text view) must be mapped from the note's text without off-by-one at emoji → Task 1, Task 4.
3. A card made for section A must never be adopted after the cursor moved to section B or the note changed by even one character → Task 3.
4. An answer that arrives after the person closed the card, started another action, switched theme, or turned AI off → Task 3.
5. ⌘Z after an adopt restores exactly the original text and selection state, and the note saved in the store matches the text view after the adopt and after the undo → Task 4.

---

### Task 1: What an action works on

**Files:**
- Create: `Sources/ReaderCore/NoteSection.swift`
- Test: `Tests/ReaderCoreTests/NoteSectionTests.swift`

**Interfaces:**
- Produces:

```swift
public struct NoteTarget: Equatable, Sendable {
    public enum Kind: Sendable { case selection, section }
    public let kind: Kind
    public let range: NSRange        // UTF-16, the text to rewrite (the heading line is not in it)
    public let text: String
    public let insertionOffset: Int  // UTF-16 offset right after the range, for adding a paragraph after it
}
public enum NoteSection {
    /// nil when the selection or the section has no text apart from white space and the heading.
    public static func target(in note: String, selection: NSRange) -> NoteTarget?
}
```

- [ ] **Step 1: Write the failing tests** (whole-value comparisons on the range and text): a selection (non-empty) is the target as typed, with kind `.selection`; a cursor in the middle of a body under `# 見出し` gives the text under the heading up to the next heading, without the heading line; a cursor on the heading line itself gives the section under it; the text before the first heading is a section (kind `.section`, no heading to skip); two sections, cursor at the end of the first (just before the next `#`) belongs to the first; a `#` in the middle of a line is not a heading; `#` followed by no space still counts as a heading (the note's own rule: a line that starts with `#`); a heading with no body or only blank lines gives `nil`; an empty note gives `nil`; a selection of only spaces gives `nil`; CRLF notes keep their `\r\n` in the range and the text; emoji and combining marks: the UTF-16 range starts and ends on character boundaries; a cursor offset past the end is clamped; trailing blank lines are not part of the text but the range ends at the end of the last non-blank line.
- [ ] **Step 2: Run** `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter NoteSectionTests`. Expected: compile errors.
- [ ] **Step 3: Implement** by scanning lines (`NSString` line ranges, so UTF-16 and CRLF are kept exactly). **Step 4: Run again.** Expected: pass.
- [ ] **Step 5: Commit** (`feat: find the text a note action works on (N5)`).

### Task 2: The prompts, the budget, and cleaning

**Files:**
- Create: `Sources/ReaderCore/NoteActionPrompt.swift`
- Test: `Tests/ReaderCoreTests/NoteActionPromptTests.swift`

**Interfaces:**
- Produces:

```swift
public enum NoteAction: Sendable, Equatable { case clearer, essence }
public enum NoteActionPrompt {
    public static let textLimit = 1_300, outputTokenLimit = 700
    public enum Outcome: Equatable, Sendable {
        case request(SuggestionPrompts.Request, wasCut: Bool)
        case tooLong          // clearer only
        case noText
    }
    public static func make(_ action: NoteAction, text: String, goal: String) -> Outcome
    /// clearer: the rewritten text, white space trimmed, wrapping quotes removed; essence: at most three lines, list marks removed, each as `・…`.
    public static func clean(_ raw: String, for action: NoteAction) -> String?
}
```

- [ ] **Step 1: Write the failing tests.** Clearer: a text of exactly 1,300 characters is accepted; 1,301 gives `.tooLong`; blank gives `.noText`; the request does not contain the goal; the instructions are fixed text (compared to a literal so a change is deliberate), under 300 characters, and tell the model to keep facts, numbers, negations and hedges ("分からない" must stay uncertain), to keep the first person, and to output only the rewritten text. Essence: a longer text is cut at 1,300 `Character`s with `wasCut == true` (an emoji at the boundary is not split), the goal is in the prompt when it is not blank and absent when it is; the instructions ask for exactly three short lines. `clean`: clearer removes control and invisible characters (not the zero width joiner), trims, unwraps one pair of quotes, returns nil for blank; essence: numbered, dashed, starred and 「・」 lines become `・…`, blank lines are dropped, more than three lines are cut to three, fewer than one gives nil, a single long line stays one line.
- [ ] **Step 2: Run, see them fail. Step 3: Implement. Step 4: Run again.**
- [ ] **Step 5: Commit** (`feat: the prompts and budget for note actions (N5)`).

### Task 3: The action model

**Files:**
- Create: `Sources/ReaderCore/NoteActionModel.swift`
- Test: `Tests/ReaderCoreTests/NoteActionModelTests.swift`

**Interfaces:**
- Consumes: `ThemeAssistant`, `NoteSection`, `NoteActionPrompt`, `withDeadline`, the `FakeAssistant` of the existing tests.
- Produces:

```swift
@Observable @MainActor public final class NoteActionModel {
    public struct Card: Equatable, Sendable { public let action: NoteAction; public let target: NoteTarget; public let noteText: String; public let answer: String; public let wasCut: Bool }
    public enum Reason: Equatable, Sendable { case disabled, unsupported, assetsMissing, noText, tooLong }
    public enum State: Equatable, Sendable { case idle, working(NoteAction), ready(Card), unavailable(Reason), failed }
    public private(set) var state: State
    public init(assistant: (any ThemeAssistant)?, isEnabled: @escaping @MainActor () -> Bool, deadline: Double = 20)
    public func request(_ action: NoteAction, note: String, selection: NSRange, goal: String)
    /// Called whenever the note text or the selection changes: a card that no longer matches is dropped, a request that is running is dropped.
    public func noteDidChange(note: String, selection: NSRange)
    public func cancel(); public func reset()
    /// The card if it still matches `note` and `selection` exactly; adopting must use this, never `state` alone.
    public func currentCard(note: String, selection: NSRange) -> Card?
}
```

- [ ] **Step 1: Write the failing tests** with the fake assistant. Success for each action; nothing is called by itself; setting off gives `.unavailable(.disabled)` with no call; the setting turned off while working drops the answer; unavailable model and missing assets; failure, blank answer and a 0.05 s deadline give `.failed` and the model works again; `.tooLong` and `.noText` give no call; `noteDidChange` with a different note text or selection drops a ready card and a running request (a held fake that ignores cancellation, answering later, is not shown); the same text and selection keep the card; `currentCard` returns nil after one character of difference; a second `request` replaces the first; `cancel` and `reset` drop late answers; the store is not an input at all (the model has no store).
- [ ] **Step 2: Run, see them fail. Step 3: Implement.** **Step 4: Run again, then a mutation check** (remove the match check in `currentCard`; remove the staleness token): the named tests must fail.
- [ ] **Step 5: Commit** (`feat: ask the on-device model for a note action, and drop a card that no longer matches (N5)`).

### Task 4: The native bridge and undo

**Files:**
- Create: `Sources/RSSReader/NoteTextHandle.swift`
- Modify: `Sources/RSSReader/NoteEditor.swift`, `Sources/RSSReader/ReaderView.swift` (N4's adopt)
- Test: `Tests/ReaderUITests/NoteTextHandleTests.swift`

**Interfaces:**
- Produces: `@MainActor final class NoteTextHandle` with `var selectedRange: NSRange?`, `var string: String?`, and `func replace(_ range: NSRange, with text: String) -> Bool` (an undoable edit; false when no text view is mounted); `NoteEditor` takes a handle and attaches it with a small `NSViewRepresentable` background that walks to the editor's `NSTextView`.

- [ ] **Step 1: Write the failing tests** on a real `NSTextView` in a window (no SwiftUI needed for the first ones): `replace` changes only the range (CRLF, emoji and combining marks around it unchanged), the text view's undo manager has an undo step, `undo` restores the exact original string, `redo` re-applies, selection after the edit is at the end of the inserted text; a failed `shouldChangeText` returns false and changes nothing; and a SwiftUI test: with the real `NoteEditor` hosted in a window, the handle finds the text view, a replace updates `Theme.note` in the store (through the editor's binding), and `undo` puts the old text back in the store too.
- [ ] **Step 2: Run, see them fail. Step 3: Implement. Step 4: Run again.** If the text view's changes do not reach the store through the binding, the editor observes the text view's change notification and saves; record what was needed.
- [ ] **Step 5: Move N4's adopt** onto `replace(_:with:)` at the insertion offset (zero-length range) when the handle is mounted; the store save path stays as the fallback. Update the N4 note in the user guide (undo now works).
- [ ] **Step 6: Commit** (`feat: a native bridge so adopting into the note is one undo step (N5)`).

### Task 5: The action bar and the card

**Files:**
- Create: `Sources/RSSReader/NoteActionBar.swift`
- Modify: `Sources/RSSReader/ThemeViews.swift` (`ThemeNotePane`), `Sources/RSSReader/ReaderView.swift`, `Sources/RSSReader/RSSReaderApp.swift`, `Sources/RSSReader/ReaderSettingsView.swift` (the AI description)
- Test: `Tests/ReaderUITests/ThemeReaderTests.swift` (a new suite `NoteActionTests`)

**Interfaces:**
- Produces: `NoteActionBar(state:canAct:onAction:onAdopt:onAnother:onClose:)`; all buttons use `.buttonStyle(.borderless)` so a test can press them.

- [ ] **Step 1: Write the failing UI tests** (fake assistant injected; `pumpRunLoop` waits; each test alone-safe): the bar is absent with AI off and present with AI on; with the cursor in a section, 「わかりやすく」 shows a card; 「採用」 replaces exactly that section's text, keeps the heading and the other sections, and the store's note equals the text view; ⌘Z (via the text view's undo manager) restores the original; 「3行の要点」 inserts three 「・」 lines after the section; moving the cursor (a selection change) or typing one character drops the card; 「別の案」 asks again; 「閉じる」 drops the card; with a text over 1,300 characters 「わかりやすく」 shows the too-long message and makes no call. (Anything that needs the model to answer over several run-loop turns is covered in Task 3; here the fake answers at once and the test pumps until the card is ready, if that works under `pumpRunLoop`; if main-actor tasks cannot run during the pump, the test drives `NoteActionModel` directly and presses only the adopt buttons.)
- [ ] **Step 2: Run, see them fail. Step 3: Implement.** **Step 4: Run the whole suite and each new UI test alone.** `bash scripts/build-app.sh release`.
- [ ] **Step 5: Exercise a synthetic instance** (own data directory, `open -n`; confirm it is the synthetic one first; a separate-bundle-ID copy is fine). If computer use is not allowed, say so and list what stays unchecked. A throwaway probe of the real model with the two prompts on synthetic text is welcome (record the outputs and times).
- [ ] **Step 6: Commit** (`feat: two note actions below the note, adopted only by choice and undoable (N5)`).

### Task 6: Documents, verification, review

**Files:**
- Modify: `docs/specification.md` (§5.1, the screen table, PRD-06), `docs/architecture.md`, both user guides, the roadmap row N5; create `docs/decisions/0016-note-actions.md` (decisions 1, 3 to 7 above) and `docs/verification/2026-10-10-note-actions.md`.

- [ ] **Step 1:** Update the documents; `git diff --check`; whole suite; release build.
- [ ] **Step 2: One independent review** of a fixed commit with `docs/review-checklist.md` and the Review Focus above (the risk is a wrong range being replaced, and a stale card being adopted). Fix Critical and Important findings test-first in one pass.
- [ ] **Step 3:** Push the branch and open the PR (English), with what it does not include and the unverified list.

## Unverified after this PR (stated in the PR)

- Real summaries and rewrites on real notes (the experiment used one synthetic note; the rewrite once changed a hedge). Real Japanese IME while the bar is used; whether ⌘Z behaves the same inside an IME composition. VoiceOver, Reduce Motion, a real window if computer use is not allowed, macOS 27.0 support floor, macOS 26 CI.
- That every new UI test runs in a whole run (see the constraint above).

## Not in this PR

"What is missing" and "an opposing view" (decision 1), a chat, several sections at once, translation, the system Writing Tools, an answer cache, editor scale (PR 10), and the removal of the unreachable question code (N2b).
