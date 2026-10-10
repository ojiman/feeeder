# L1: the note as an inspector — verification record

**Result: PASS on synthetic data in headless windows (macOS 27 / Swift 6.4, local). Not checked in a real window. One headless result is a known gap: the sidebar did not collapse in a headless host (see below).** One independent review of the fixed commit is recorded at the end.

| Check | Result |
|---|---|
| Whole suite (`swift test`, local) | 287 tests in 38 suites, no failure reported. As in the earlier records, a whole run does not reliably report every UI test, so each UI test below was also run alone |
| `ReaderWorkspaceTests` | pass: a theme's note is closed at first, open or closed is remembered per theme, and opening or closing it leaves the theme's reader (selected article, scroll memory) alone |
| `NoteLayoutTests` | pass (renamed calls `noteOpened` / `noteClosed`): fold on open, the person's choice holds while the note stays open, unfold on close |
| `ThemeArticleSwitcherTests` | pass: the end rules of the chevrons (the entries API of N3 is removed because the menu is gone) |
| UI tests, each alone | `theNoteIsAbsentWhileClosedAndBesideTheListAndTheReaderWhenOpen`, `theChevronsMoveBetweenTheThemesArticlesAndStopAtTheEnds`, `theListAndTheChevronsAgreeOnTheShownArticle`, `aShownArticleThatLeftTheThemeDoesNotBreakThePanel`, `theSummaryButtonIsShownWhenAIIsOnAndAbsentWhenItIsOff`, `theButtonNeedsAnArticleAndAsksForNothingUntilPressed`, `aSummaryIsMadeOnRequestAndAdoptedIntoTheNoteAndUndoBringsItBack`, `aFailureOffersToTryAgainAndMovingToAnotherArticleClearsTheCard`, and the five N5 tests: all pass |
| Release build | builds |

## Where the old N3 to N5 tests went

| Old test | Now |
|---|---|
| `noteFaceShowsTheNoteInsteadOfTheArticleList` | replaced by `theNoteIsAbsentWhileClosedAndBesideTheListAndTheReaderWhenOpen` (the list now stays) |
| `faceSwitchSitsBelowTheToolbarAndChangesBothColumns` | removed: the face switch is gone |
| `theTopBarMovesBetweenTheThemesArticlesFromTheNoteFace` | `theChevronsMoveBetweenTheThemesArticlesAndStopAtTheEnds` |
| `theArticleChosenOnTheNoteFaceIsTheOneTheArticlesFaceShows` | replaced by `theListAndTheChevronsAgreeOnTheShownArticle` (there is one reader, so the property is now that the list and the chevrons agree) |
| `aShownArticleThatLeftTheThemeDoesNotBreakTheTopBar` | `aShownArticleThatLeftTheThemeDoesNotBreakThePanel` |
| `theNotesSelectionComesBackAfterAFaceRoundTrip` | removed: opening and closing the inspector cannot be driven in a headless window (the toolbar button is not in the headless tree). Not verified, see below |
| `theSwitchIsHidden…` / `theSwitchIsShown…` (the 「原文｜AI要約」 switch) | `theSummaryButtonIsShownWhenAIIsOnAndAbsentWhenItIsOff` |
| `openingTheSummaryAsksForNothing…` and `movingToAnotherArticleKeeps…` | `theButtonNeedsAnArticleAndAsksForNothingUntilPressed` and `aFailureOffersToTryAgainAndMovingToAnotherArticleClearsTheCard` |
| (new: the N4 request and adopt, which the old card's buttons could not be pressed for) | `aSummaryIsMadeOnRequestAndAdoptedIntoTheNoteAndUndoBringsItBack` |
| the five N5 tests | unchanged apart from opening the note through the harness |
| N3's `ReaderTopBar` and `ArticleSummaryCard` | removed with their views |

## Not verified

- **The sidebar folding.** With the note open the harness sets the split view's visibility to the two-column state (confirmed by a trace), but the headless split view stayed expanded, and the sidebar button of the list column was not found in the headless tree either. It may be a limit of the headless host (the same mechanism was used by N3 and was never observed). The folding rule is tested as a pure value (`NoteLayoutTests`); its effect is not.
- **A real window:** the inspector's width and resizing, a narrow window (960 points), the toolbar button and `⌥⌘I`, the look of the panel, the toolbar height, the cursor when closing and reopening the note.
- Real Japanese IME in the note, VoiceOver, Reduce Motion, the macOS 27.0 support floor, macOS 26 CI.
- ⌘Z of ordinary typing in the note keeping the store in step with the text view (open since N5).
