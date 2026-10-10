# N6: Claude hand-off with the goal and the note — verification record

**Result: PASS on synthetic data (macOS 27 / Swift 6.4, local), with a fake launcher. No real launch of Claude Desktop was made, so what Claude does with the package, and how useful its review is, are not verified.** One independent review of the fixed commit is recorded at the end.

| Check | Result |
|---|---|
| Whole suite (`swift test`, local) | 293 tests in 40 suites (after the review fixes), no failure reported. As in the earlier records, a whole run does not reliably report every UI test, so the two new UI tests were also run alone |
| `AIPackageTests` (theme part) | pass: the goal and the note are included only when asked, under labels that say they were written by the user; the review request appears only when the note is included, the source request otherwise; a goal-only, note-only or neither package; text that looks like markers (CRLF, an `END_PACKAGE` line, a forged `END_THEME`, emoji) is kept byte for byte and the real marker appears once; a 60,000-line note splits losslessly; a goal-or-note package with no source builds, lives a day, and is valid after an hour but not after a day; with neither and no source it is refused; editing the included note, the included goal, renaming the theme, or deleting the theme invalidates the review (a note edit when only the goal is included does not); a theme name with a forged `Note (written by the user):` line is folded into one line |
| `ClaudeHandoffTests` (theme part) | pass: a copy is removed with its theme or when a source article leaves the theme, and is kept when the note, goal or name are edited (a snapshot, until its 24 hours); a copy of the goal and note alone is kept a day, has no `questionIDs`, and goes with its theme; an old copy without theme fields and one with `questionIDs` of questions that no longer exist both still reconcile (and still obey the source rule); a changed package is not opened; the clean-up runs when the reload after deleting a theme fails |
| `HandoffDefaultsTests` (3) | pass: the toolbar entry offers the goal and leaves the note off, the note panel's button switches both on, an empty goal or note is off and disabled |
| Mutation checks | Removing the re-check of the theme context in `reconcile` fails `aReviewBecomesInvalidWhenWhatItContainsChanges` and `aThemeCopyIsOpenedOnlyAfterItsPackageIsStillValid`; truncating the note in the package fails four tests |
| UI tests (alone) | `theNotePanelsButtonOpensTheReviewWithTheGoalAndTheNote` (the sheet's package text contains the goal and the note and the review request) and `theButtonIsAbsentWhenThereIsNothingToHandOver`: pass |
| Release build | builds |

## Not verified

- A real launch into Claude Desktop with the goal and the note, and the usefulness of Claude's review (the review request tries to avoid the on-device model's main failure, but nothing here shows how Claude behaves). Other versions, plans or routes than the one that was checked (Claude Desktop 2.19675.0 / Pro / Cowork). A very large note through the Cowork route.
- The review screen's switches in a real window: pressing them, the layout, and the text of the notice. The headless test checks the opening and the package text, not the toggles.
- IME and VoiceOver on the review screen; macOS 26 CI.
