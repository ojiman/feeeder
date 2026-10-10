# N4: AI summary in the reader — verification record

**Result: PASS for the logic on synthetic data (macOS 27 / Swift 6.4, local). The card's buttons (make a summary, adopt) were not pressed in any window, real or headless; they are covered below the view level only.** One independent review of the fixed commit is recorded at the end.

| Check | Result |
|---|---|
| Whole suite (`swift test`, local) | 260 tests in 35 suites, no failure reported. As in the N3 record, a whole run does not reliably run every UI test, so the UI tests below were also run alone |
| `ArticleSummaryPromptTests` (6) | pass: the 3,000-character cut counts Characters (an emoji, a combining mark and CRLF at the boundary are not split), a blank body gives no request, the instructions are fixed text under 300 characters, the answer is cleaned |
| `ArticleSummaryModelTests` (9) | pass: nothing is called by itself; the setting off means no call; the setting turned off while working drops the answer; unavailable model and missing assets are explained without a call; failure, a blank answer and the 0.05 s deadline give `failed` and the model works again; reset and cancel drop a late answer (also from a fake that ignores cancellation); a second request replaces the first; no text means no call, and the theme's recorded RSS summary is used only for a member article; a long body is marked cut; the store, the note and read state are untouched |
| Mutation checks | Removing the post-answer setting check fails `switchingTheSettingOffWhileWorkingDropsTheAnswer`. Removing the post-answer staleness check changes nothing, because cancelling already makes `withDeadline` throw first (the check is a second guard) |
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
