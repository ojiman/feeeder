# N3: Two panes and the folding sidebar — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This project keeps one supervised implementer ([decision 0002](../../decisions/0002-single-supervised-writer.md)).

**Goal:** On the note face of a theme, the person writes in the middle column and reads in the right column, with the sidebar folded away to give both room. The right column has a top bar to move between the theme's articles without leaving the note.

**Architecture:** Mostly view state and small pure rules. The reader state (selected article, scroll memory) becomes one per theme, shared by both faces, so changing the article on the note face is not lost when the person goes back to Articles. A pure `NoteLayout` value decides when the sidebar folds and when it comes back. A reader top bar (previous, next, a menu of the theme's articles) is added above the reader on the note face only. The existing keyboard rule already keeps shortcuts out of text input; it is made precise so a read-only reader does not block them and the editable note always does.

**Tech Stack:** Swift 6, SwiftUI, AppKit (`NSTextView` focus), Swift Testing. No new dependency.

**Spec:** [decision 0013](../../decisions/0013-goal-and-note-for-themes.md) (point 4), [roadmap Part 1c, row N3](2026-10-10-theme-notes.md), PRD §2 (screen), §3.3. Merging this plan approves it. Plan approval is not product acceptance.

**Language:** New project text is in English (AGENTS.md, "Language"). App labels stay Japanese; they are quoted as they appear, with a short English gloss.

## Decisions for you (merging approves them)

1. **The sidebar folds when you enter the note face, and comes back when you leave it.** It uses the standard split-view folding (it follows Reduce Motion). While you are on the note face you can bring it back and fold it again; your last choice holds until you leave the face. Going to Articles always shows it. Switching themes does not change the choice for the face you are on.
2. **How to bring the sidebar back.** A small button (`sidebar.left`) at the left of the 「記事｜ノート」 switch, on the note face only. It is in the content, not in the window toolbar, so the toolbar does not change height (the problem fixed in #42). The standard Hide Sidebar button stays removed.
3. **The reader's top bar is on the note face only.** It has: previous and next article buttons, and a menu with the title of the current article that lists all articles of the theme (a check mark on the current one). With no article selected it shows 「記事を選ぶ」 ("Choose an article") and the menu. Nothing opens by itself when you enter the note face. The top bar is where N4 puts the 「原文｜AI要約」 switch. The Articles face does not get a top bar: it has the list.
4. **Keys on the note face.** `j` / `k` (and `s`, `t`, `b`, `v`, `m`) work whenever you are **not** typing in an editable field: never in the note, never with IME text in progress, never in a sheet. They work when the reader or the top bar has the focus. So that you can move between articles while writing, two keys work even inside the note: `⌥⌘↓` (next) and `⌥⌘↑` (previous). I chose these because the text system does not use them; this is checked on a real window (see "Unverified").
5. **The toolbar buttons follow the reader.** Star, 「テーマに入れる」 (Add to theme), and open in browser act on the article shown in the right column, on both faces. On the note face they are enabled when an article is shown. Opening the original page (`v`) works on the note face too and covers only the right column; the note stays visible. 「Claudeで開く…」 is unchanged.
6. **Column widths on the note face.** Middle column: minimum 320, preferred 460, maximum 800 points (it is 280 / 400 / 640 on the Articles face). The reader keeps its minimum of 360. The window minimum stays 930 points, so with the sidebar folded both columns fit. Widths are remembered by the system per face as they are today; if a width jump between faces looks bad on a real window, I fall back to the Articles widths and say so in the PR.
7. **The note keeps its cursor and selection** when you go to Articles and come back, and when the sidebar folds or unfolds. I keep the selection in memory per theme (not saved to disk). If the system `TextEditor` selection cannot be restored reliably on macOS 26 and 27, I do not ship a half-working version: I keep only the text (always safe, it is saved on every change) and say that the cursor is not kept.
8. **Not in this PR.** The AI summary switch (N4), the note actions (N5), the hand-off with the note (N6), the note editor scale (PR 10), a Reeder-style fade of the sidebar, a keyboard shortcut or a View-menu item for the sidebar, and removal of the unreachable question code (N2b).

## Global Constraints

- Support floor macOS 27.0; build floor and CI stay macOS 26.6 / Swift 6.3.3. No macOS 27-only API. Avoid method references as `Binding` setters and mutated captured `var`s in `@MainActor` closures (the Swift 6.3.3 compiler crashes on both).
- Shortcuts never fire while the person types or composes text (marked text) or while a sheet is open (existing rule, [ReaderKeyboardCommands](../../../Sources/RSSReader/ReaderKeyboardCommands.swift)). The toolbar must not change height with the selection (#42): no toolbar items appear or disappear.
- Text the person typed in the note is never dropped. The note is saved on every change (N2); nothing in this PR may recreate the editor while it holds unsaved composition.
- Tests use synthetic data and temporary databases only. One theme per PR. Failing tests first. Commit and PR text in English. Add the attribution line the session gives.
- The specification and architecture are updated in the same PR, with a decision record if the key rule or layout contract changes (AGENTS.md, Definition of done 6). Do not push to `main`, sign, or release. After implementation and one review of a fixed commit, push the branch and open the PR without asking.

## Review Focus

1. Typing `j`, `k`, `s`, `t`, `v`, `m`, `b` in the note, including Japanese IME composition with those letters, must type the letter and never act → Task 4.
2. Previous and next at the first and last article, an empty theme, and the theme's last article removed from the theme while it is shown on the note face → Task 2, Task 5.
3. The article chosen on the note face is the one Articles shows after switching back, and the reader's scroll position per article is kept in both directions → Task 1.
4. Folding and unfolding the sidebar, and a face round trip, do not lose the note's text; the cursor is kept or the PR says it is not → Task 3, Task 6.
5. A narrow window (930 points) with the sidebar shown by hand on the note face still shows the note and the reader; Reduce Motion removes the fold animation → Task 3, Task 6.

---

### Task 1: One reader state per theme, shared by both faces

**Files:**
- Modify: `Sources/ReaderCore/ReaderWorkspaceState.swift`, `Sources/RSSReader/ReaderView.swift` (`setFace`, `enterScope`, `shortcutsEnabled`)
- Test: `Tests/ReaderCoreTests/ReaderWorkspaceTests.swift`

**Interfaces:**
- Produces: `ReaderWorkspaceState.isReading(_:)` is true for every scope including a theme's note face. `switchFace(of:to:rememberingReader:)` saves the reader when leaving either face. The note face no longer blocks `rememberReader`.

- [ ] **Step 1: Write the failing tests.** In `ReaderWorkspaceTests`: (a) switch to `.note`, then `rememberReader(second, in: .theme(id))`, switch back to `.articles`: `reader(in:)` returns `second`; (b) leaving the note face saves the reader (the old test that said it never overwrites is replaced by this one); (c) the face of another theme is unaffected; (d) `isReading(.theme(id))` is true on both faces. Run `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ReaderWorkspaceTests`: the old expectations fail.
- [ ] **Step 2: Implement.** Remove the `face == .articles` conditions in `isReading`, `rememberReader` and `switchFace`. In `ReaderView`, `enterScope` restores the saved reader for both faces and no longer forces `columnVisibility = .all` (Task 3 owns it).
- [ ] **Step 3: Run the workspace and UI tests.** Expected: pass. Update the UI test `faceSwitchSitsBelowTheToolbarAndChangesBothColumns` where it assumed shortcuts are off on the note face.
- [ ] **Step 4: Commit** (`refactor: one reader state per theme, shared by both faces (N3)`).

### Task 2: Moving between a theme's articles

**Files:**
- Create: `Sources/ReaderCore/ThemeArticleSwitcher.swift`
- Test: `Tests/ReaderCoreTests/ThemeArticleSwitcherTests.swift`

**Interfaces:**
- Consumes: `ReaderNavigation.move`, `ReaderStore.themeArticleIDs(themeID:keeping:)`.
- Produces: `ThemeArticleSwitcher.entries(store:themeID:selection:) -> [Entry]` (id, title, isCurrent), and `canMovePrevious` / `canMoveNext` for a selection in a list. Pure over IDs and titles.

- [ ] **Step 1: Tests.** The list of a theme in order; the current one marked; a selection that is not in the theme is listed first and marked (it is kept visible, as `themeArticleIDs(keeping:)` does today); `canMovePrevious` is false on the first and with no selection and an empty list, `canMoveNext` is false on the last; with no selection `move` opens the first article. An empty theme gives no entries.
- [ ] **Step 2: Run, see them fail. Step 3: Implement. Step 4: Run, pass.**
- [ ] **Step 5: Commit** (`feat: the list and the end rules for moving between a theme's articles (N3)`).

### Task 3: The folding rule

**Files:**
- Create: `Sources/ReaderCore/NoteLayout.swift`
- Modify: `Sources/RSSReader/ReaderView.swift`
- Test: `Tests/ReaderCoreTests/NoteLayoutTests.swift`

**Interfaces:**
- Produces:

```swift
public struct NoteLayout: Equatable, Sendable {
    public private(set) var sidebarFolded: Bool            // what the person sees now
    public init()                                           // sidebar shown
    public mutating func enterNoteFace()                    // folds
    public mutating func leaveNoteFace()                    // shows
    public mutating func toggleSidebar()                    // the person's choice on the note face
    public var visibility: ColumnVisibility { get }         // .all or .doubleColumn (an own enum, so ReaderCore has no SwiftUI)
}
```

- [ ] **Step 1: Tests.** Entering folds; leaving shows; a manual show on the note face holds until leaving; entering again folds again; leaving twice and entering twice are harmless; a theme switch while on the note face (note face of another theme) keeps the person's last choice. Run: compile errors.
- [ ] **Step 2: Implement** the value type, and in `ReaderView`: a `@State var noteLayout`, set from `setFace` and from a scope change into or out of a note face, mapped to `columnVisibility` with `withAnimation(reduceMotion ? nil : .default)`. Add the `sidebar.left` button at the left of `ThemeFacePicker` (note face only, `.help("サイドバーを表示／隠す")`, an accessibility label). Check that `SidebarTitlebarControls` (the add and refresh buttons in the title bar) follow `columnVisibility` as they already do.
- [ ] **Step 3: Run the tests and the UI tests.** Expected: pass.
- [ ] **Step 4: Commit** (`feat: the sidebar folds on the note face and the person can bring it back (N3)`).

### Task 4: The keyboard rule

**Files:**
- Modify: `Sources/ReaderCore/ReaderSelectionState.swift` (`ReaderShortcutPolicy`), `Sources/RSSReader/ReaderKeyboardCommands.swift`, `Sources/RSSReader/ReaderView.swift`
- Test: `Tests/ReaderCoreTests/ReaderSelectionTests.swift`, `Tests/ReaderUITests/ThemeReaderTests.swift`

**Interfaces:**
- Produces: `ReaderShortcutPolicy.permits(textInput:markedText:sheet:originalPage:)` is unchanged; the caller now passes `textInput` as "the first responder is an **editable** text view or a text field". New commands: `⌥⌘↓` next and `⌥⌘↑` previous, honored while the note is focused, never with marked text, never in a sheet.

- [ ] **Step 1: Failing tests.** Pure: the policy table as it is (a regression guard). UI test with a synthetic window: with the note editor first responder, `keyDown` of `j`, `k`, `s`, `t`, `v`, `m`, `b` does not change the selection or the star; with marked text set in the editor (`setMarkedText`) the same keys do nothing and `⌥⌘↓` does nothing; with the reader's read-only text view as first responder, `j` moves; `⌥⌘↓` moves from the note.
- [ ] **Step 2: Implement.** `permits(sheet:originalPage:)` treats a non-editable `NSTextView` as not text input; `ReaderView` adds the two key bindings with the note-face and marked-text rules.
- [ ] **Step 3: Run the UI tests.** Expected: pass. **Step 4: Commit** (`feat: shortcuts work in the reader on the note face and never in the note (N3)`).

### Task 5: The reader top bar, the toolbar buttons, and the original page on the note face

**Files:**
- Create: `Sources/RSSReader/ReaderTopBar.swift`
- Modify: `Sources/RSSReader/ReaderView.swift`
- Test: `Tests/ReaderUITests/ThemeReaderTests.swift`

**Interfaces:**
- Consumes: `ThemeArticleSwitcher`, `ReaderNavigation.move`, `selectArticle`.
- Produces: `ReaderTopBar(entries:onPrevious:onNext:onChoose:)`, shown above the reader on the note face.

- [ ] **Step 1: Failing UI tests.** On the note face: the bar shows the current title; next moves the reader and the bar; previous at the first article is disabled; the menu lists all articles and choosing one opens it; with no selection the bar shows 「記事を選ぶ」; removing the shown article from the theme (through the store) keeps the bar and reader consistent (the article stays shown and is listed, marked as outside the theme) and does not crash; the star, theme and browser buttons are enabled on the note face when an article is shown; going back to Articles shows the article chosen on the note face.
- [ ] **Step 2: Implement.** `article` in the toolbar closure no longer depends on `isReading`. Opening the original page works on the note face; `enterScope` no longer closes it when the face changes only if the article stays the same (`OriginalPageState.selectionChanged` already closes it for a different article).
- [ ] **Step 3: Run the tests.** Expected: pass. **Step 4: Commit** (`feat: a top bar to move between a theme's articles from the note face (N3)`).

### Task 6: Column widths, the note's cursor, and a real window

**Files:**
- Modify: `Sources/RSSReader/ReaderView.swift`, `Sources/RSSReader/NoteEditor.swift`
- Test: `Tests/ReaderUITests/ThemeReaderTests.swift`

- [ ] **Step 1: Failing tests.** The note's selection is restored after a face round trip and after a sidebar fold and unfold (a synthetic window: set a selection, switch, switch back, read the selection). If the `TextEditor(text:selection:)` API does not restore the selection on macOS 26 and 27, record that in the ledger and in the PR, remove the selection code, and keep the text-only guarantee (decision 7).
- [ ] **Step 2: Implement** the widths (decision 6) and the selection memory per theme in `NoteEditor`.
- [ ] **Step 3: Run the whole suite.** `bash scripts/build-app.sh release`.
- [ ] **Step 4: Exercise a synthetic instance** with its own data directory (`open -n …`; confirm it is the synthetic one first, AGENTS.md): fold on entering the note face, bring the sidebar back with the button, move between articles with the bar, `⌥⌘↓` while the cursor is in the note, a window at 930 points, and Reduce Motion on (System Settings) if reachable. Background input could not operate the segmented switch before; if it still cannot, say so and list what stays unchecked.
- [ ] **Step 5: Commit** (`feat: wider note column and the note keeps its cursor (N3)`).

### Task 7: Documents, verification, review

**Files:**
- Modify: `docs/specification.md` (the screen table, §2 and §3.3 for the note face and the keys, PRD rows if they name the layout), `docs/architecture.md` (the reader state, `NoteLayout`, the key rule), `docs/user-guide.md` and `docs/user-guide.ja.md` (the note face, the sidebar button, the keys), the roadmap row N3
- Create: `docs/verification/2026-10-10-theme-two-panes.md` (the result in its first three lines, then a table; what stays unverified)

- [ ] **Step 1:** Update the documents. Replace the "temporary layout until N3" text from N2.
- [ ] **Step 2:** `git diff --check`; the full suite; the release build.
- [ ] **Step 3: One independent review** of a fixed commit (the layout is not a store or deletion change, but the key rule touches text input and IME, so the reviewer gets docs/review-checklist.md and the Review Focus above). Fix Critical and Important findings test-first, in one pass.
- [ ] **Step 4:** Push the branch and open the PR (English). The PR states what it does not include and the unverified list.

## Unverified after this PR (stated in the PR)

- Real Japanese IME with `j k s t v m b` in the note, and the `⌥⌘↓` / `⌥⌘↑` keys inside the note (the text system may use them on some input sources).
- VoiceOver on the top bar, the menu and the sidebar button; Reduce Motion for the fold animation; the look of the width change between faces on a real window.
- macOS 27.0 support floor (the local toolchain is macOS 27, CI is 26.6).

## Not in this PR

The AI summary switch (N4), note actions (N5), the hand-off with the note (N6), the note editor scale (PR 10), a fade of the sidebar, a View-menu or keyboard shortcut for the sidebar, and the removal of the unreachable question code (N2b).
