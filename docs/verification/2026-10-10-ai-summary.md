# N4: AI summary in the reader — verification record

**Result: PASS for the logic on synthetic data (macOS 27 / Swift 6.4, local). The card's buttons (make a summary, adopt) were not pressed in any window, real or headless; they are covered below the view level only.** One independent review of the fixed commit e4110f3 is recorded at the end.

| Check | Result |
|---|---|
| Whole suite (`swift test`, local) | 261 tests in 35 suites, no failure reported. As in the N3 record, a whole run does not reliably run every UI test, so the UI tests below were also run alone |
| `ArticleSummaryPromptTests` (6) | pass: the 3,000-character cut counts Characters (an emoji, a combining mark and CRLF at the boundary are not split), a blank body gives no request, the instructions are fixed text under 300 characters, the answer is cleaned |
| `ArticleSummaryModelTests` (9) | pass: nothing is called by itself; the setting off means no call; the setting turned off while working drops the answer; unavailable model and missing assets are explained without a call; failure, a blank answer and the 0.05 s deadline give `failed` and the model works again; reset and cancel drop a late answer (also from a fake that ignores cancellation); a second request replaces the first; no text means no call, and the theme's recorded RSS summary is used only for a member article; a long body is marked cut; the store, the note and read state are untouched |
| Mutation checks | Removing the reset on article change fails `movingToAnotherArticleKeepsTheSwitchAndClearsTheModel`; removing the reset on leaving 「AI要約」 fails `openingTheSummaryAsksForNothingAndTheLinkGoesBackToTheArticle` (both tests first put the model in a non-idle state). Removing the post-answer setting check fails `switchingTheSettingOffWhileWorkingDropsTheAnswer`. Removing the post-answer staleness check changes nothing, because cancelling already makes `withDeadline` throw first (the check is a second guard) |
| `NoteInsertionTests` (9) | pass: empty note, start, end (with and without a trailing line break), middle of a line, before a blank line, CRLF notes, emoji and combining marks, the cursor after the block, offsets clamped, and the whole adopt step from a UTF-16 selection end |
| UI tests, each run alone (`AISummaryTests`, `NoteFaceTests`, `ThemeReaderTests`) | pass: the switch is hidden with AI off; opening 「AI要約」 asks for nothing and writes nothing, and the 「原文を見る」 link goes back; moving to another article keeps the switch; the earlier N3 tests still pass |
| Real on-device model, a throwaway probe through `FoundationModelsGenerator` with the real prompt on two synthetic articles | available; 3.8 s and 1.9 s. The first summary kept the numbers but **left out the risk of a lump-sum demand at the last payment**; the second repeated its short source almost word for word. Both are usable as drafts; neither added a fact. Not a quality verdict |
| Release build | builds |

## Test-infrastructure finding

While writing the UI tests I found that a UI test which suspends with `Task.sleep` after creating windows makes the whole test process exit silently (exit code 0, no result). The new and changed tests in `ThemeReaderTests.swift` therefore wait by pumping the run loop (`pumpRunLoop`) instead. Many UI tests in other files still use `Task.sleep` and still do not report in a whole run. A pump starves Swift tasks that need the main actor, so it is not a general fix: it cannot wait for the summary model to answer, which is why the model is tested outside the view. A separate task is suggested to fix it for good.

## Not verified

- The card in a window: asking for a summary with the button, the working state and 「中止」, the failure card, adopting with a real selection in the note, the label 「採用しました」, the look of the card and the switch in the top bar. The card's buttons are drawn by SwiftUI and are not reachable from a headless test; a real-window check was not allowed in this session.
- Undo of an adopt (not promised), real Japanese IME while the card is open, VoiceOver, Reduce Motion, the macOS 27.0 support floor, macOS 26 CI.
- Real summary quality on real articles (see the probe above and the [experiment](2026-10-10-note-ai-experiment.md)).

## Independent review (opus, one pass, commit e4110f3)

It traced the wiring by hand because the card's buttons cannot be pressed in a test. It found no path where a summary for one article is shown or adopted for another, after going back to 「原文」, or after AI is turned off, and none where the store or note is written without an adopt. It did not check a real window (shortcut routing, what `TextEditor` reports during IME), VoiceOver, macOS 26 CI, `FoundationModelsGenerator`, or the whole-suite run.

| Finding | Grade | Handling |
|---|---|---|
| `v` could open the original page behind the card and then every single-key shortcut stopped | Important | `openOriginal` does nothing while the summary is shown |
| `.keyboardShortcut(.defaultAction)` on 「ノートに採用」 might take Return from the note (including Return that confirms IME text) | Important (unverified) | The shortcut is removed |
| The card used the unfiltered model state; `adopt` did not check the article | Minor | The card gets the state filtered by article, and `adopt` checks it |
| A selection index from an older copy of the note would trap in `utf16Offset(in:)` | Minor | The index is checked against the end of the note first |
| The same article in another theme kept its summary | Minor | The summary is reset when the scope changes |
| The title had no limit; cleaning removed the zero width joiner of emoji sequences | Minor | Title cut to 200 characters; the joiner is kept (test first) |
| Decision 0013 said "in place of the selection" and 1,000 tokens; no record for the real choices | Minor | Decision 0015 records the insertion point, the 3,000-character budget and the limits |
| README and the guides did not say "unless you adopt" | Minor | Fixed |
| Two N4 UI tests asserted `.idle` when the model was never anything else | Minor | Rewritten to start from a non-idle state; both reset handlers now fail a test when removed |
| Inserting at a cursor in the middle of a line splits that line with blank lines | Minor (kept) | As planned and recorded in decision 0015: the text is not changed, only separated |
| No test for `adopt` or the selection-to-offset step in the view; no test for the setting check between availability and generate | Minor (deferred) | The offset rules are tested as pure text rules; the view step needs a window |
