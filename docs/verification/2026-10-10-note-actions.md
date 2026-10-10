# N5: note actions — verification record

**Result: PASS on synthetic data (macOS 27 / Swift 6.4, local), including the full adopt and undo path in a headless window with the real SwiftUI note editor. Not checked in a real window, with the real IME, or on macOS 26 CI.** One independent review of the fixed commit is recorded at the end.

| Check | Result |
|---|---|
| Whole suite (`swift test`, local) | 288 tests in 38 suites, no failure reported. As in the N3 and N4 records, a whole run does not reliably report every UI test (in the last run `aTextOverTheLimitIsRefusedForARewriteWithoutAnyCall` started and never reported), so each UI test was also run alone |
| `NoteSectionTests` (10) | pass: selection as typed, section under the cursor without its heading, cursor on a heading, text before the first heading, section ends, a `#` inside a line, blank sections give nil, CRLF, UTF-16 ranges at emoji and combining marks, clamped cursor |
| `NoteActionPromptTests` (6) | pass: 1,300 accepted / 1,301 refused for a rewrite, no goal for a rewrite, the essence cut by Character with the goal, fixed instructions under 300 characters, cleaning of a rewrite and of the three bullet lines |
| `NoteActionModelTests` (8) | pass: nothing is called by itself, both actions, off / unavailable / too long / empty give no call, failure / blank / deadline recover, the setting turned off while working drops the answer, a changed note or selection drops a card and a running request (also a late answer from a call that ignores cancellation), `currentCard` needs the exact note and selection, a second request replaces the first, cancel and reset |
| Mutation checks (model) | `currentCard` ignoring the note and selection fails `currentCardRequiresTheExactNoteAndSelection`; never dropping a ready card or a running request fails `aChangedNoteOrSelectionDropsTheCardAndTheRunningRequest` |
| `NoteTextHandleTests` (4) | pass: a replace changes only its range (CRLF, emoji, combining marks around it unchanged) and is one undo step that `undo` and `redo` move through; zero-length insert and out-of-range edits; a failed save throws and registers no step; with the real `NoteEditor` hosted, an edit reaches the store and the text view, and undo and redo reach both |
| UI tests (`NoteActionTests`, 5), each alone | pass: the bar is shown with AI on and absent with AI off; with the cursor in a section 「わかりやすく」 makes a card and 「採用」 replaces exactly that text, keeps the heading and the other section, and ⌘Z (the undo manager) restores the original in the store and the view; 「3行の要点」 inserts three 「・」 lines after the section; moving the cursor to another section, and typing, drop the card; a text over 1,300 characters is refused without a call |
| Real on-device model, a throwaway probe with the real prompts on a synthetic 5-sentence section and a synthetic goal | available; 1.7–3.7 s for a rewrite, 1.1–1.3 s for an essence. **The rewrite changed almost nothing** (a few sentence endings), so it adds little on text that is already plain. The first essence turned "考えている" (thinking about) into "選んでいる" (has chosen), a small overstatement; the second kept the uncertainty. Not a quality verdict |
| Release build | builds |

## Notes

- The plan's native bridge was redesigned while testing: editing the text view's own storage and relying on its undo manager did not undo when SwiftUI drives the view (the text stayed). The bridge now hands the whole new text to the save path and registers its own undo and redo steps (decision 0016, point 6). Finding the text view by an accessibility identifier did not work either (SwiftUI sets none until accessibility is active); it is found as the editable, non-field-editor text view, preferring the one that shows the expected note text.
- A rewrite's output cap was raised from the plan's 700 to 1,200 tokens (a rewrite of a full 1,300-character text needs about 1,000).
- Waiting in the UI tests pumps the run loop and yields (`Task.yield`), not `Task.sleep` (see the N4 record).

## Not verified

- A real window: the look and layout of the bar and card in the narrow note column, the order of focus (does pressing a button leave the text selection alone?), ⌘Z and ⇧⌘Z through the real Edit menu, and ⌘Z while Japanese text is being composed. The headless test uses the undo manager directly.
- VoiceOver, Reduce Motion, the macOS 27.0 support floor, macOS 26 CI, real notes and real rewrites.
- N4's adopt through the same bridge is covered only by the shared code (its buttons are not pressable in a test).

## Independent review (opus, one pass, commit f3f3383)

It checked: that `adopt()` compares the store's note and the text view's current selection with the card exactly (safe even if an `onChange` is missed); the model's tokens, cancel, deadline, setting re-check and that it never writes; UTF-16 arithmetic in `NoteSection` and the insertion offsets with CRLF, emoji and combining marks; resets on theme, face and AI change; the failed-save path of an adopt. It did not check a real window, the real IME, what AppKit does with undo entries when the text view is rebuilt, or macOS 26 CI.

| Finding | Grade | Handling |
|---|---|---|
| An undo restored a whole-note snapshot without checking the current note, so it could delete text typed after the adopt, or overwrite another theme's note | Critical | The undo and redo steps now apply only while the saved note equals what the step produced. Test first: `anUndoNeverPutsAnOldCopyOverNewerText` failed, then passed; removing the guard fails it again |
| `replace()` did not check that the text view shows the saved note (composition, a rolled-back save, several editors) | Important | It refuses and the caller uses the plain save; `anEditIsRefusedWhenTheTextViewDoesNotShowTheSavedNote` |
| A selection ending in a line break lost it on rewrite (two paragraphs merged) | Important | White space at both ends of a selection is not part of the target (test first) |
| An undo that could not be saved was silent and still registered a redo | Important | It is reported through `onUndoError` and registers no redo (`anUndoThatCannotBeSavedIsReportedAndNoRedoIsRegistered`) |
| A long rewrite could come back cut off at the token cap and then replace the whole section | Important | A rewrite shorter than half of an input of 200+ characters is treated as failed (test first); the deadline is 30 seconds |
| The essence of a selection was inserted mid-line | Minor | Inserted after the line the selection ends in (test first) |
| A rewrite's line breaks were not converted for a CRLF note; the instruction could translate an English section | Minor | Converted; the instruction keeps the language |
| Settings text and README did not mention the actions | Minor | Fixed |
| One test changed the shared AI setting in `UserDefaults`, so a parallel suite could see AI off (this made an N4 UI test fail once in a whole run) | Minor | `ReaderView` takes its settings store as a parameter and the tests use private stores |
| The card does not show which text 「採用」 will replace; finding the text view walks the windows on each redraw | Minor (deferred) | Kept |
| No test removes the `currentCard` check in `adopt()` and fails | Minor (deferred) | The check is tested in the model; the view calls it as the first line of `adopt()` |

## Not verified (added by the review)

- Whether ⌘Z of ordinary typing in the note keeps the store in step with the text view. A headless probe that typed with `insertText` and undid it was inconclusive (the undo did nothing there), and an earlier probe saw the view revert while the store kept the typed text. If that happens with real typing it is a flaw of the note editor's binding from N2, not of the actions. It needs a real window.
