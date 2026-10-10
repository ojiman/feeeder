# S1 notes (S1a: remove what V1 no longer has) — verification record

**Result: PASS on synthetic data for S1a (macOS 27 / Swift 6.4, local). Not checked in a real window, with the real Japanese input, on macOS 26 CI, or on a real library.** S1b (the rename and the layout fixes) extends this record.

Plan: `docs/superpowers/plans/2026-10-11-s1-notes.md`. Decision: `docs/decisions/0019-v1-simplification-notes.md`.

| Check | Result |
|---|---|
| A store written by the build before decision 0019 (a theme with a goal, a question and an answer, a starred and read article) opens with the new schema, keeps feeds, articles, read state and the Star, the theme name and its note, drops the question and the goal, accepts a write and reopens | PASS, `PreNoteStoreUpgradeTests` (opt-in: `FEEEDER_PRE0019_FIXTURE_DIR`, fixture made by `scripts/prepare-v1-store-fixture.sh` from `52429b4`). The same test passed before any code change (fixture sanity) and after each removal |
| Whole suite (`swift test`) | 195 tests in 32 suites pass |
| UI suites run alone (`ThemeReaderTests`, `NotePanelTests`, `HandoffEntryTests`) | pass. A whole run does not reliably report UI tests |
| The panel has only the header and the editor: no summary button, no summary card, no action bar | `theNotePanelHasNoSummaryButtonAndNoActionBar` |
| The schema has no question model | `theSchemaHasNoQuestionModel` |
| The Claude package has no goal anywhere; the note is still included only when asked; a package of the note alone lives a day | `theNoteIsIncludedOnlyWhenAskedAndNoGoalIsEverMentioned`, `aPackageOfTheNoteAloneHasNoSourcesAndLivesADay` |
| Failure injection for the note and theme changes still passes (a failed save is not success, recovery on the first call) | `ReaderStoreTests`, `ThemeTests` (the question steps were removed, the note steps kept) |

## Not verified

- Any real window (the layout of the panel without the goal strip and the cards, the sidebar toggle button in its new place).
- A real library (the owner's); a store older than the build before 0019 (older stores with unmigrated questions lose them).
- Real Japanese input in the note; VoiceOver; macOS 26 CI.
- `ArticleSummaryModel`, `ArticleSummaryPrompt` and `NoteInsertion` have unit tests but no screen until S2.
