# N6: Claude hand-off with the goal and the note — verification record

**Result: PASS on synthetic data (macOS 27 / Swift 6.4, local), with a fake launcher. No real launch of Claude Desktop was made, so what Claude does with the package, and how useful its review is, are not verified.** The independent review of the fixed commit is recorded at the end of this file once it has been done.

| Check | Result |
|---|---|
| Whole suite (`swift test`, local) | 291 tests in 39 suites, no failure reported (after the review fixes below). As in the earlier records, a whole run does not reliably report every UI test, so the two new UI tests were also run alone |
| `AIPackageTests` (theme part) | pass: the goal and the note are included only when asked, under labels that say they were written by the user; the review request appears only when the note is included, the source request otherwise; a goal-only, note-only or neither package; text that looks like markers (CRLF, an `END_PACKAGE` line, a forged `END_THEME`, emoji; `BEGIN_THEME` still appears once — the forged `END_THEME` line is kept as the user's text, see decision 0018 point 6) is kept byte for byte; a 60,000-line note splits losslessly; a goal-or-note package with no source builds, lives a day, and is valid after an hour but not after a day; with neither and no source it is refused; editing the included note, the included goal, renaming the theme, or deleting the theme invalidates the review (a note edit when only the goal is included does not); a theme name with a forged `Note (written by the user):` line is folded into one line |
| `ClaudeHandoffTests` (theme part) | pass: a copy is removed with its theme or when a source article leaves the theme, and is kept when the note, goal or name are edited (a snapshot, until its 24 hours); a copy of the goal and note alone is kept a day, has no `questionIDs`, and goes with its theme; an old copy without theme fields and one with `questionIDs` of questions that no longer exist both still reconcile (and still obey the source rule); a changed package is not opened; the clean-up is started when the reload after deleting a theme fails (the copy itself goes only once a reload succeeds, or at its 24 hours) |
| `HandoffDefaultsTests` (3) | pass: the toolbar entry offers the goal and leaves the note off, the note panel's button switches both on, an empty goal or note is off and disabled |
| Mutation checks | Removing the re-check of the theme context in `reconcile` fails `aReviewBecomesInvalidWhenWhatItContainsChanges` and `aThemeCopyIsOpenedOnlyAfterItsPackageIsStillValid`; truncating the note in the package fails the tests that compare the package text with the note |
| UI tests (alone) | `theNotePanelsButtonOpensTheReviewWithTheGoalAndTheNote` (the sheet's package text contains the goal and the note and the review request) and `theButtonIsAbsentWhenThereIsNothingToHandOver`: pass |
| Release build | builds |

## Not verified

- A real launch into Claude Desktop with the goal and the note, and the usefulness of Claude's review (the review request tries to avoid the on-device model's main failure, but nothing here shows how Claude behaves). Other versions, plans or routes than the one that was checked (Claude Desktop 2.19675.0 / Pro / Cowork). A very large note through the Cowork route.
- The review screen's switches in a real window: pressing them, the layout, and the text of the notice. The headless test checks the opening and the package text, not the toggles.
- IME and VoiceOver on the review screen; macOS 26 CI.

## Independent review (opus, fixed commit c3bae6a, lens: what leaves the Mac)

No Critical finding. It ran the three ReaderCore suites (39 tests, pass). It did not run the UI tests, the release build, macOS 26 CI or a real launch.

| Finding | Outcome |
|---|---|
| Important: spec and architecture status lines still said the note hand-off is not built | Fixed (`docs/specification.md`, `docs/architecture.md`) |
| Goal alone with no note and no article asked Claude to analyse articles that are not there | Fixed test first: a goal-only request text (`aPackageOfTheGoalOrTheNoteAloneHasNoSourcesAndLivesADay` failed, then passed) |
| `.empty` error told the person to pick an article when a note exists | Fixed with the same test: the message now also names the goal and the note |
| UI test for the absent button could pass without finding the chevrons | Fixed: it now asserts the chevrons are found |
| Wording: "the clean-up runs" when the reload after a theme deletion keeps failing | Wording corrected here and in `docs/architecture.md`; the behavior predates N6 |
| Goal and note read before the reload check in `build` | No change: `build` always goes on to `aiSources`, which reloads first and throws, so no package is made from stale text; copy, export and open also re-check |
| A note that contains the line `END_THEME <id>` gives two such lines; the goal and note have no byte-length line | Deferred (Minor). Decision 0018 point 6 keeps marker-like lines as the user's data. A length line like the sources' is a possible later hardening |
| The fixed Claude prompt still mentions Source IDs for a package with no source | Deferred; the launch prompt is outside this PR (listed as unverified in the PR) |
| Plan wanted "no goal" and "empty note" beside each disabled switch; the screen shows one combined line | Deferred (Minor) |
