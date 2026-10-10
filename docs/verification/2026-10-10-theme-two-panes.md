# N3: two panes and the folding sidebar — verification record

**Result: PASS on synthetic data in headless windows (macOS 27 / Swift 6.4, local). Not checked in a real window, with the real IME, or on macOS 26 CI.** One independent review of the fixed commit is recorded at the end.

| Check | Result |
|---|---|
| Whole suite (`swift test`, local) | 236 tests in 32 suites, no failure reported. **Caveat:** some UI tests start but never report a result in a whole run (also on `main`; see below), so each UI test below was also run alone |
| `ReaderWorkspaceTests.bothFacesOfAThemeShareOneReader` | failed first, passes: the article chosen on the note face is the one the articles face shows, with its scroll memory |
| `ThemeArticleSwitcherTests` (4), `NoteLayoutTests` (4) | pass: list order, current mark, an article that left the theme stays listed, the ends, fold on entry, hold the person's choice, follow the window |
| `ShortcutResponderTests` (3) | pass: an editable text view or field is text input, a read-only reader is not, marked text blocks every shortcut |
| UI tests run alone: `theTopBarMovesBetweenTheThemesArticlesFromTheNoteFace`, `theArticleChosenOnTheNoteFaceIsTheOneTheArticlesFaceShows`, `aShownArticleThatLeftTheThemeDoesNotBreakTheTopBar`, `theNotesSelectionComesBackAfterAFaceRoundTrip`, `faceSwitchSitsBelowTheToolbarAndChangesBothColumns`, `noteFaceShowsTheNoteInsteadOfTheArticleList` | each passes. Removing the selection binding makes the selection test fail (mutation check) |
| Release build (`scripts/build-app.sh release`) | builds |

## Silent UI tests (found while testing, not caused by this PR)

In a whole `swift test` run, some tests in `Tests/ReaderUITests` print "started" and never "passed" or "failed", yet the run ends with "passed". On `main` (3fbf4a7) these were `editableFieldsKeepTyping`, `originalPageKeepsColumnsAndSidebarControlsMounted` and the thumbnail-width cases. The set changes from run to run. Each passes when run alone. The cause is not found; a separate task is suggested. Until it is fixed, a whole-run "passed" does not prove that every UI test ran.

## Not verified

- A real window: the folding animation and Reduce Motion, the sidebar button, the top bar, the widths (320 / 460 / 800), and the look of the face switch with its extra button. A check by computer use was not allowed in this session.
- Real Japanese IME with `j k s t v m b` in the note, and `⌥⌘↓` / `⌥⌘↑` inside the note (the key equivalents of the top bar buttons).
- VoiceOver on the top bar, the menu and the sidebar button; the macOS 27.0 support floor; macOS 26 CI.
- The toolbar buttons acting on the note face's article (no toolbar exists in the headless window; the code no longer ties them to the face).
