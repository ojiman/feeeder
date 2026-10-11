# S1 notes (S1a: remove what V1 no longer has; S1b: notes replace themes) — verification record

**Result: PASS on synthetic data for S1a and S1b (macOS 27 / Swift 6.4, local); a short real-window check of S1b (below) found one open problem: the note panel is about 270 pt wide at a 1,240 pt window, below its 300 pt minimum, and dragging its edge could not be tried. Not checked with the real Japanese input, on macOS 26 CI, or on a real library.**

Plan: `docs/superpowers/plans/2026-10-11-s1-notes.md` (removed with S1b; in Git history). Decision: `docs/decisions/0019-v1-simplification-notes.md`.

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

# S1b: notes replace themes

| Check | Result |
|---|---|
| Old stores open: one made before decision 0019 (`52429b4`) and one made after S1a (`ae8aa78`) keep feeds, articles, read state and Stars; the themes (names, notes, article records) are not kept; the new store accepts a write and reopens | PASS, `PreNoteStoreUpgradeTests` with both fixtures (opt-in) |
| The title of a note: first non-empty line, marks removed; empty, marks-only and space-only notes are 「新規ノート」; CRLF, CR, U+2028; emoji and combining marks whole; a 10,000-character line returned whole; a mark in the middle kept | PASS, `NoteTitleTests` (5; written first, failed to compile, then passed) |
| The stored entities are `Note` and `NoteArticle` only; the sidebar order is the last edit first with a fixed tie order; saving to a missing note is an error | PASS, `NoteTests` |
| A panel is open at first and a closed one stays closed per note while the app runs | PASS, `ReaderWorkspaceTests` (failed first); opening the panel does not take the keyboard: `openingThePanelDoesNotTakeKeyboardFocus` |
| The sidebar folds when a panel opens only below 1,300 pt, a hand choice holds until the panel closes, a resize while open folds and unfolds | PASS, `NoteLayoutTests` (6). The fold itself cannot be seen in a headless window |
| The panel width: clamped to 300-640, a missing, text or NaN value falls back to 380, a saved value returns after a restart, tiny changes are not written again | PASS, `NotePanelWidthTests` (4; written first) |
| A managed Claude copy written before the rename: one with theme sources (old selection key `themeArticle`) is removed by maintenance and nothing fails later; one that names its note under the old key `themeID` (note alone, or articles only) is read as its note, so it is kept while the note exists and removed with it | PASS, `aCopyWrittenBeforeTheRenameToNotesIsRemovedWithoutFailingMaintenance`, `aCopyWrittenBeforeTheRenameStillFollowsItsNote` (failed first) |
| The package: no goal, no title line, `BEGIN_NOTE`/`END_NOTE`, the note text verbatim | PASS, `AIPackageTests` |
| Whole run | 207 tests in 34 suites (ReaderCore) pass; UI suites run alone: `NoteReaderTests` 10, `NotePanelTests` 5, `HandoffEntryTests` 2 pass |
| Release build and `git diff --check` | build succeeds; clean |

## Real-window check (a copy of the app with its own bundle identifier and synthetic data; the owner's library and running app were not touched)

| Observed | Result |
|---|---|
| 「新しいノート」 makes an empty note, selects it, and its panel opens at once | seen |
| Typing `# 金利の話` and a line: the sidebar row and the window subtitle become 「金利の話」 at once | seen |
| 「Claudeでレビューを頼む」 appears once the note has text and stays on one line | seen |
| The sidebar toggle button in the bar above the list folds and shows the sidebar | seen |
| The panel measured about 270 pt wide in a 1,240 pt window (sidebar about 217, list about 393, article about 361), with the sidebar shown or folded | **problem**: below the 300 pt minimum; the cause is not known. A hard `frame(minWidth: 300)` pushed the panel off the right edge and was reverted. The fold threshold (1,300 pt) was set from this measurement |
| Dragging the edge of the panel; the width after a relaunch; the fold in a narrow window | **not tried**: background input does not reach the divider, and a real mouse drag was stopped because other windows overlapped the screen |

## Not verified

- Dragging the panel edge, the saved width after a relaunch, and the fold in a narrow window (all need a real mouse and a real window).
- Real Japanese input in the note, VoiceOver, macOS 26 CI, the owner's real library.
- The decision of the plan to show the first article when a note is opened was **not built** (displaying an article marks it as read, so entering a note would mark an article the person never chose).

## Independent review (opus, fixed commit b1a6f3e)

No Critical finding; the old-store checks were re-run by the reviewer with both fixtures. Fix pass:

| Finding | Outcome |
|---|---|
| Important: a note-only managed copy written before the rename (old key `themeID`) was unreadable: never removed, and maintenance failed at every launch (an article-only one stopped following its note) | Fixed test first: `aCopyWrittenBeforeTheRenameStillFollowsItsNote` failed, then passed; the metadata reads `themeID` as `noteID` |
| Important: the saved panel width recorded widths the person did not choose (the first width, or one squeezed below the minimum), so the default 380 could become 300 | Fixed test first: `NotePanelWidth.shouldSave` (inside 300-640, differs from the first width seen, not already saved); the view uses it |
| Minor, fixed: an unknown window width (0) folded the sidebar at the first appearance; a long first line made a tall sidebar row and `NoteTitle` scanned the whole text per call; words that changed meaning in the rename (「このノートにはノートがありません」, the editor placeholder, the picker placeholder, the demo text); `toggleNote` named twice; a broken sentence in the architecture; a duplicate `failNext` in a test | Fixed (`anUnknownWidthDoesNotFoldAndTheFirstMeasurementDecides`; `NoteTitle` stops at the first non-empty line) |
| Minor, deferred: a sidebar change made by the window (a divider drag) is not treated as the person's choice (the app cannot tell it from its own change); a new note from the picker with a name made of marks or markup gets a different title than typed, and several empty notes look the same; the picker toast has no line limit; the panel width is stored in `UserDefaults.standard`, shared with a synthetic run of the same bundle; the delete-then-reload-fails and the from-a-scope-change focus cases are not tested | Ledgered for S2 or later |

