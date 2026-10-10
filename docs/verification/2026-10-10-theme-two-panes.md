# N3: two panes and the folding sidebar — verification record

**Result: PASS on synthetic data in headless windows (macOS 27 / Swift 6.4, local). Not checked in a real window, with the real IME, or on macOS 26 CI.** One independent review of the fixed commit 39882ba is recorded at the end.

| Check | Result |
|---|---|
| Whole suite (`swift test`, local) | 236 tests in 32 suites, no failure reported. **Caveat:** some UI tests start but never report a result in a whole run (also on `main`; see below), so each UI test below was also run alone |
| `ReaderWorkspaceTests.bothFacesOfAThemeShareOneReader` | failed first, passes: the article chosen on the note face is the one the articles face shows, with its scroll memory |
| `ThemeArticleSwitcherTests` (4), `NoteLayoutTests` (4) | pass: list order, current mark, an article that left the theme stays listed, the ends, fold on entry, hold the person's choice, follow the window |
| `ShortcutResponderTests` (3) | pass: an editable text view or field is text input, a read-only reader is not, marked text blocks every shortcut |
| UI tests run alone: `theTopBarMovesBetweenTheThemesArticlesFromTheNoteFace`, `theArticleChosenOnTheNoteFaceIsTheOneTheArticlesFaceShows`, `aShownArticleThatLeftTheThemeDoesNotBreakTheTopBar`, `theNotesSelectionComesBackAfterAFaceRoundTrip`, `faceSwitchSitsBelowTheToolbarAndChangesBothColumns`, `noteFaceShowsTheNoteInsteadOfTheArticleList` | each passes. Removing the selection binding makes the selection test fail (mutation check) |
| Release build (`scripts/build-app.sh release`) | builds |

## Silent UI tests (found while testing, not caused by this PR)

In a whole `swift test` run, UI tests start but do not always report a result, yet the run ends with "passed". The same happens on `main` (3fbf4a7: `editableFieldsKeepTyping`, `originalPageKeepsColumnsAndSidebarControlsMounted`, the thumbnail-width cases). The set that goes missing changes from run to run and with small changes to the tests; a filtered run of `ThemeReaderTests` ends after `faceSwitchSitsBelowTheToolbarAndChangesBothColumns` with exit code 0 and no summary. Each of these tests passes when it is run alone with `--filter`. For N3 this means: **the new UI tests (`NoteFaceTests`, now a suite of its own) pass alone, but a whole run, and so possibly CI, does not reliably run them.** A timer to keep the run loop alive and a hidden window did not fix it. The cause is not found; a separate task is suggested. Until it is fixed, a whole-run "passed" does not prove that every UI test ran.

## Not verified

- A real window: the folding animation and Reduce Motion, the sidebar button, the top bar, the widths (320 / 460 / 800), and the look of the face switch with its extra button. A check by computer use was not allowed in this session.
- Typing `j k s t v m b` in the note, and the keys in the reader. The key guards are tested as pure rules (`ShortcutResponderTests`, `ReaderShortcutPolicy`) only: a test that sends key events to a headless window hung, so it was dropped. `j` and `k` with the focus in the reader (a read-only text view) rely on the key press reaching SwiftUI and are not verified.
- Real Japanese IME with those letters, and `⌥⌘↓` / `⌥⌘↑` inside the note (the key equivalents of the top bar buttons).
- VoiceOver on the top bar, the menu and the sidebar button; the macOS 27.0 support floor; macOS 26 CI.
- The toolbar buttons acting on the note face's article (no toolbar exists in the headless window; the code no longer ties them to the face).

## Independent review (opus, one pass, commit 39882ba)

It checked: the sidebar fold loop (none), start on the note face, theme switches, the shared reader state both ways, the original page across faces, removing the shown article from the theme, the toolbar height (#42), the removal of `isReading`, the architecture text. It did not check a real window, the real IME, VoiceOver, Reduce Motion, whether key equivalents fire during marked text or with a popover key, macOS 26 CI, or the release build.

| Finding | Grade | Handling |
|---|---|---|
| The new UI tests did not run in a whole run | Important | Moved into their own suite; each passes alone; the record above says plainly that a whole run does not prove they ran. The underlying problem is a separate task |
| `j` / `k` did nothing on the note face (handlers only on the article list), but the docs said they work | Important | Root-level `j` / `k` handlers for the note face, same guard as `s t m b v`. Whether the key reaches them from the reader's text view is **not verified** (listed above) |
| No test fails if the keyboard guards break | Important | The responder rule is tested as pure logic. A headless key-event test hung and was dropped. Stays unverified (listed above) |
| `inTheme` was computed but not shown | Minor | The menu now adds 「（テーマ外）」 to an article that left the theme |
| The ⌥⌘ keys did not check the theme picker | Minor | They do not act while the picker is open or while marked text is present |
| The selection could point past the text after a failed save | Minor | The selection is cleared on a save error |
| Leftover blank lines; the record said a review was recorded | Minor | Fixed |
