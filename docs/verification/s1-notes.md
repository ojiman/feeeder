# S1 notes (S1a: remove what V1 no longer has) — verification record

**Result: PASS on synthetic data for S1a (macOS 27 / Swift 6.4, local). Not checked in a real window, with the real Japanese input, on macOS 26 CI, or on a real library.** S1b (the rename and the layout fixes) extends this record.

Plan: `docs/superpowers/plans/2026-10-11-s1-notes.md`. Decision: `docs/decisions/0019-v1-simplification-notes.md`.

| Check | Result |
|---|---|
| A store written by the build before decision 0019 (a theme with a goal, a question and an answer, a starred and read article) opens with the new schema, keeps feeds, articles, read state and the Star, the theme name and its note, accepts a write and reopens (that the question and the goal are gone is shown by `theSchemaHasNoQuestionModel` and by a read-only sqlite look at the fixture, which holds an unmigrated question row and a goal; the opt-in test does not assert the drop itself) | PASS, `PreNoteStoreUpgradeTests` (opt-in: `FEEEDER_PRE0019_FIXTURE_DIR`, fixture made by `scripts/prepare-v1-store-fixture.sh` from `52429b4`). The same test passed before any code change (fixture sanity) and after each removal |
| Whole run (`swift test`) | 195 tests in 32 suites pass (the ReaderCore tests; the two opt-in tests are skipped without their fixture variables) |
| UI suites run alone (`ThemeReaderTests`, `NotePanelTests`, `HandoffEntryTests`) | 9 tests in 3 suites pass. A whole run does not reliably report UI tests |
| Release build (`bash scripts/build-app.sh release`) and `git diff --check` | build succeeds; no whitespace errors |
| The panel has only the header and the editor: no summary button, no summary card, no action bar | `theNotePanelHasNoSummaryButtonAndNoActionBar` |
| The schema has no question model | `theSchemaHasNoQuestionModel` |
| The Claude package has no goal anywhere; the note is still included only when asked; a package of the note alone lives a day | `theNoteIsIncludedOnlyWhenAskedAndNoGoalIsEverMentioned`, `aPackageOfTheNoteAloneHasNoSourcesAndLivesADay` |
| Failure injection for the note and theme changes still passes (a failed save is not success, recovery on the first call) | `ReaderStoreTests`, `ThemeTests` (the question steps were removed, the note steps kept) |

## Not verified

- Any real window (the layout of the panel without the goal strip and the cards, the sidebar toggle button in its new place).
- A real library (the owner's); a store older than the build before 0019 (older stores with unmigrated questions lose them).
- Real Japanese input in the note; VoiceOver; macOS 26 CI.
- `ArticleSummaryModel`, `ArticleSummaryPrompt` and `NoteInsertion` have unit tests but no screen until S2.

## Independent review (opus, fixed commit c81fc1f)

No Critical finding; the store upgrade was re-run by the reviewer and passes. Fix pass:

| Finding | Outcome |
|---|---|
| Important: `renameTheme` returned silently for a theme that no longer exists (the old `updateTheme` threw) | Fixed test first: `unknownThemeIsANoOp` now expects `missingTheme` (it failed, then passed) |
| Important: goal words left in the UI (review button help, delete confirmation, retention text in Settings) | Fixed; `grep -rn ゴール Sources` is empty |
| Important: architecture and user guides out of step with the code (the English paragraph on package content, a cursor-memory sentence, no statement of the data loss) | Fixed; both guides now say that goals, and the questions of builds that had them, are dropped at first launch and that the `Feeeder` folder should be backed up first. The cursor memory of the note is gone with the removed selection binding (accepted: it only served the removed actions) |
| Important: two UI tests for behavior that stays were deleted (note absent while closed; a theme lists only its articles) | Restored (`theNoteIsAbsentWhileClosedAndBesideTheListAndTheReaderWhenOpen`, `aThemeListsOnlyItsOwnArticlesWithTheNoteClosed`); they pass |
| Minor: `theNotePanelHasNoSummaryButtonAndNoActionBar` could not fail on the old code | Accepted: the removal is guaranteed by the deleted types no longer compiling; the test guards against the panel regrowing buttons |
| Minor: unused `createTheme(name:adding: [UUID])`, unused `OnDeviceAISetting.isEnabled`, the Settings AI switch has no visible effect until S2, the list moves by the bar's height when the note is toggled | Deferred to S2, S1b and S4 (the unused code goes with S4; the bar is looked at in a real window after S1b) |
