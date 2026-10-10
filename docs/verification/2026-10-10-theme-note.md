# N2: the note and the migration — verification record

**Result: PASS on synthetic data (macOS 27 / Swift 6.4, local); not verified on a real library, with the real Japanese IME, VoiceOver, or macOS 26 CI.** One independent review of the fixed commit b77227d is recorded at the end.

| Check | Result |
|---|---|
| Full test suite (`swift test`, local, macOS 27 / Swift 6.4) | 228 tests in 30 suites passed (after the review fixes) |
| Migration tests (`LegacyNoteMigrationTests`, `LegacyNoteTextTests`, the two failure-injection lists in `ThemeTests`, the review test in `AIPackageTests`) | pass: full move and removal, second run does nothing, existing note kept, evidence of a removed member skipped, failed save changes nothing and a retry works, a failed verification deletes nothing, the hook runs once, a review built from old questions is invalid afterwards |
| Mutation checks | Skipping the verification makes `aVerificationFailureDeletesNothingAndSavesNothing` fail; dropping the existing note makes `existingNoteTextIsKeptAndTheOldTextFollowsIt` fail |
| Older store: a store written by `main` (3fbf4a7, themes with understanding, questions with answers and evidence, a multi-line question) opened with this branch's release app (`open -n`, separate bundle ID copy, data directory `/private/tmp/feeeder-n2-run`) | The notice 「問いと答えをノートにまとめました（2件のテーマ）」 showed; `sqlite3` shows each note as expected, the answer's own `# ` line kept, the multi-line question split into heading and rest, no questions left, understanding empty |
| Note face in a real window | Not reached: background input cannot operate the segmented switch. The headless UI test `faceSwitchSitsBelowTheToolbarAndChangesBothColumns` shows the note, and the selected article stays visible on the right |
| Save time of a 100,000-character note (`aLongNoteSavesAndItsTimeIsRecorded`) | about 2 ms for the save call (local). This does not measure typing in the editor |

## Not verified

- The migration on the owner's real library. Copy the data folder first.
- Real Japanese IME in the note editor (composition, candidates, long text), VoiceOver, Reduce Motion, the macOS 27.0 support floor, macOS 26 CI.
- Typing speed in a very long note, and the note face visually in a real window.

## Independent review (opus, one pass, commit b77227d)

It checked: the order of plan, check, save and removal; one save and no await between plan and save; `reloadIfNeeded`; failed save and rollback; a second run; evidence pruning; the hook and the launch order with the hand-off reconcile; `saveNote` and its failure lists; emoji, ZWJ, flags and marker-like lines in the composed text; removed code; the documents; the full suite (224 tests then). It did not check macOS 26 CI, a running app, the real IME, whether NSTextView keeps CRLF on paste, VoiceOver, or the hand-off reconcile internals.

| Finding | Grade | Handling |
|---|---|---|
| Text ending in CR or CRLF, or starting with a combining mark, failed the migration's own check, so the whole library would never migrate | Important | Fixed test-first: `textEndingInCarriageReturnsOrStartingWithACombiningMarkPassesTheCheck` and `anAnswerThatEndsInCRLFStillMigrates` failed, then passed with a literal text search |
| A reload that fails after a successful save was reported as a failed migration ("nothing was removed") | Important | Fixed test-first: `aReloadThatFailsAfterASuccessfulSaveIsStillASuccess` |
| No test failed when the existing-note guard was removed | Minor | Added `theExistingNoteMustSurviveInTheComposedText`; removing the guard now fails it (mutation check) |
| The spec said the old text is removed after the save; the code does both in one save | Minor | Wording fixed |
| The heading's surrounding spaces are trimmed | Minor | Doc comment corrected; kept (a heading line) |
| The check is weak: a short piece that appears elsewhere would pass | Minor (deferred) | Kept; the full-string tests compare the whole output for each shape |
| The retry's new alert depends on the timing of SwiftUI alert dismissal | Minor (deferred) | The next launch also retries; not tested without a window |
