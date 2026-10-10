# L1: The note as an inspector — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This project keeps one supervised implementer ([decision 0002](../../decisions/0002-single-supervised-writer.md)).

**Goal:** The middle column is always the article list. The note opens beside the article as the standard inspector. The summary of the article is a button inside the note panel. Everything N3 to N5 gave (the folding sidebar, one reader state per theme, the summary, the note actions with undo) keeps working in the new layout.

**Architecture:** `ThemeFace` (articles or note) becomes a per-theme "note is open" flag in `ReaderWorkspaceState`. `ReaderView` stops swapping the middle column and the reader; it keeps one list and one reader and adds `.inspector` on the reader. `ThemeNotePane` becomes `NotePanel` (header with the goal and previous/next, the summary button and its card, the editor, the action bar). `NoteLayout` (the folding rule) is driven by the inspector's open state. Nothing about data, models, prompts or the bridge changes.

**Tech Stack:** Swift 6, SwiftUI (`.inspector`, `NavigationSplitView`), AppKit where tests need it, Swift Testing. No new dependency, no API above the macOS 26.6 build floor (`.inspector` is macOS 14).

**Spec:** [decision 0017](../../decisions/0017-note-beside-the-article.md), [roadmap Part 1d, row L1](2026-10-10-theme-notes.md), [decision 0013](../../decisions/0013-goal-and-note-for-themes.md) (the parts that stand), [0015](../../decisions/0015-article-summary-details.md), [0016](../../decisions/0016-note-actions.md). Merging this plan approves it. Plan approval is not product acceptance.

**Language:** New project text is in English (AGENTS.md, "Language"). App labels stay Japanese; they are quoted as they appear, with a short English gloss.

## Decisions for you (merging approves them)

1. **The screen.** Sidebar, article list, reader, and — when open — the note inspector on the right. The list is the same list in every scope; in a theme it shows that theme's articles, with the goal strip on top (as on the old articles face). `j` / `k` and the other keys work on the list as before.
2. **Opening the note.** A toolbar button (an icon of a note beside a page) and `⌥⌘I` ("Show / Hide Inspector", the Apple convention). The button is **always in the toolbar** and is disabled outside a theme, so the toolbar never changes height (the problem of #42). Whether a theme's note is open is remembered per theme while the app runs (not after a restart); a theme starts with the note closed.
3. **Removed.** The 「記事｜ノート」 face switch, the reader's top bar (previous, next, article menu), and the 「原文｜AI要約」 switch. Moving between articles is the list again.
4. **Sidebar.** Opening the note folds the sidebar (the rule from N3); closing it brings the sidebar back. While the note is open a small sidebar button sits at the left of the goal strip so the person can bring it back. (The `sidebar.left` button of N3 moves there.)
5. **The note panel, top to bottom.** (a) A header: the theme's name, the goal (click to edit, as the strip), and two small chevron buttons for the previous and next article (keeping `⌥⌘↑` / `⌥⌘↓` while writing, which the top bar had). (b) A button 「記事から要約する」 that summarizes the article shown in the reader; its card appears under the header and is adopted into the note as in N4 (insertion after your selection, source line, one ⌘Z step). (c) The editor. (d) The two note actions of N5, under the editor, with their card. The review area of L4 will go between (c) and (d); nothing is built for it now.
6. **Sizes.** The inspector is at least 300, preferably 380, at most 640 points wide. The window's minimum width goes from 930 to **960** points; with the sidebar folded, the list (280) + the reader (360) + the inspector (300) just fit. The note column no longer needs the wider "note face" widths of N3 (the list column goes back to 280 / 400 / 640).
7. **What stays.** Everything in the data and AI rules: goal, note, migration, summary on request, the note actions, adopting by choice, undo through the bridge, the Settings switch (AI off hides the summary button and the action bar). The summary's article is the one in the reader, so a card is dropped when another article is selected, as before.
8. **Not in this PR.** The styled display of headings and lists (L2), the review (L3, L4), the system Writing Tools (L5), the hand-off with the note (N6), the note editor scale (PR 10), the removal of the unreachable question code (N2b).

## Global Constraints

- Support floor macOS 27.0; build floor and CI stay macOS 26.6 / Swift 6.3.3. Avoid method references as `Binding` setters and mutated captured `var`s in `@MainActor` closures in tests.
- The toolbar must not change height with the selection (#42): no toolbar item appears or disappears. Shortcuts never fire while the person types or composes text; `⌥⌘↑` / `⌥⌘↓` and `⌥⌘I` are key equivalents that work inside the note too, but not during marked text, not while the theme picker is open, and not in a sheet.
- Text typed in the note is never dropped; the editor must not be recreated while it holds unsaved composition (opening or closing the inspector, or folding the sidebar, must keep the editor's text and cursor).
- No behavior of N3 to N5 is dropped silently: each test that covered it is moved to the new layout or replaced by a test of the same property, and the PR lists them.
- Tests: synthetic data and fake assistants only. One theme per PR. Failing tests first. Commit and PR text in English. Add the attribution line the session gives. Do not push to `main`, sign, or release. After implementation and one independent review of a fixed commit, push the branch and open the PR without asking.
- UI tests: a UI test that suspends with `Task.sleep` can stop the whole test process silently (see the N4 record); wait by pumping the run loop and yielding, put UI tests in suites of their own, run each alone, and say which ran how. Use private settings stores (`defaults:`) so a test never changes the Mac's real setting.

## Review Focus

1. Opening and closing the inspector, folding the sidebar, and switching theme keep the note's text and cursor, and never recreate the editor under composition → Task 3, Task 5.
2. The summary card and the note action card are dropped when the article, the theme, the note text, the selection, the AI setting, or the inspector's open state changes; a late answer never shows → Task 4.
3. The reader keeps showing the right article after opening the note, closing it, and switching themes (one reader state per theme) → Task 1, Task 3.
4. `j` / `k` on the list still work with the note open; typing in the note never triggers a shortcut; `⌥⌘I`, `⌥⌘↑`, `⌥⌘↓` work inside the note but not while composing → Task 5.
5. A narrow window (960 points) with the note open still shows the list, the reader and the note; the toolbar does not change height; AI off hides the summary button and the action bar → Task 3, Task 5.

---

### Task 1: The note's open state replaces the face

**Files:**
- Modify: `Sources/ReaderCore/ReaderWorkspaceState.swift`
- Test: `Tests/ReaderCoreTests/ReaderWorkspaceTests.swift`

**Interfaces:**
- Produces: `ReaderWorkspaceState.isNoteOpen(of: UUID) -> Bool` (false by default), `mutating func setNote(open: Bool, of: UUID)`. `ThemeFace` and `face(of:)`, `switchFace` are removed. The reader state stays one per theme (`reader(in:)`, `rememberReader`), and opening or closing the note does not touch it.

- [ ] **Step 1: Write the failing tests.** Default closed; opening one theme does not open another; the open state is remembered per theme; the reader state of a theme is unchanged by opening and closing; the existing round-trip tests (selection and scroll memory survive leaving and returning to a scope) still hold without `ThemeFace`. Run: compile errors.
- [ ] **Step 2: Implement and remove `ThemeFace`.** Fix the compile errors in `ReaderView` minimally (the screen itself changes in Task 3). **Step 3: Run the workspace tests.** Expected: pass.
- [ ] **Step 4: Commit** (`refactor: a theme's note is open or closed, there is no second face (L1)`).

### Task 2: The note panel as one view

**Files:**
- Create: `Sources/RSSReader/NotePanel.swift`
- Modify: `Sources/RSSReader/ThemeViews.swift` (remove `ThemeFacePicker` and `ThemeNotePane`), `Sources/RSSReader/NoteEditor.swift` (unchanged behavior)
- Test: `Tests/ReaderUITests/ThemeReaderTests.swift` (a new suite `NotePanelTests`)

**Interfaces:**
- Consumes: `NoteEditor`, `NoteActionPanel`, `ArticleSummaryCard` (reused as the card inside the panel), `ThemeGoalStrip`.
- Produces: `NotePanel(store:themeID:selection:noteActions:handle:summaries:article:…)`: the header (name, goal, chevrons), the summary button and card, the editor, the action bar. The chevrons carry `⌥⌘↑` / `⌥⌘↓`.

- [ ] **Step 1: Write the failing UI tests** (the panel hosted alone in a window, a fake assistant, borderless AppKit buttons): the header shows the theme's name and goal; the summary button is absent with AI off and present with AI on; pressing it with an article shown asks the model once and shows the card; with no article shown the button is disabled with a short reason; 「採用」 inserts the summary at the stored selection with the source line and one ⌘Z removes it (the N4 and N5 properties, moved here); the action bar and card behave as in N5.
- [ ] **Step 2: Run, see them fail. Step 3: Implement.** The summary card is `ArticleSummaryCard` rendered inside the panel (its text no longer replaces the reader). Keep `ArticleSummaryModel` as is.
- [ ] **Step 4: Run each new test alone and the core suite. Step 5: Commit** (`feat: one note panel with the goal, the summary button, the editor and the actions (L1)`).

### Task 3: The new screen

**Files:**
- Modify: `Sources/RSSReader/ReaderView.swift`, `Sources/RSSReader/RSSReaderApp.swift`
- Delete: `Sources/RSSReader/ReaderTopBar.swift`
- Test: `Tests/ReaderUITests/ThemeReaderTests.swift`

- [ ] **Step 1: Write the failing UI tests.** In a theme: the middle column is the article list and stays so with the note open (a `NativeArticleList.Table` is in the tree in both states); the reader keeps the selected article when the note opens and closes; the note panel is absent when closed and present when open; the toolbar button exists in every scope (so the toolbar never changes) and is disabled outside a theme; outside a theme there is no inspector; the goal strip is above the list in a theme; opening the note folds the sidebar and closing it shows it again; the sidebar button appears only while the note is open.
- [ ] **Step 2: Run, see them fail.**
- [ ] **Step 3: Implement.** Remove the face logic: `onNoteFace`, `faceBinding`, `setFace`, the top bar, `paneMode`, `showsSummary`, the content-column swap, the detail-column `VStack` with the top bar, and the summary replacement of the reader. Add `.inspector(isPresented:)` with `.inspectorColumnWidth(min: 300, ideal: 380, max: 640)` on the reader, bound to `workspace.isNoteOpen`; the toolbar button; `⌥⌘I` as a key equivalent of that button; the window minimum width 960; `NoteLayout.enterNoteFace()` / `leaveNoteFace()` are called when the inspector opens and closes (rename them `noteOpened()` / `noteClosed()` with their tests). The list column widths go back to 280 / 400 / 640. Reset the summary model and the action model when the note closes, the theme changes, the article changes, or the AI setting changes (as now).
- [ ] **Step 4: Run the whole suite and each UI test alone.** `bash scripts/build-app.sh release`.
- [ ] **Step 5: Commit** (`feat: the note opens beside the article as an inspector (L1)`).

### Task 4: Move the N3 to N5 tests, and drop nothing

**Files:**
- Modify: `Tests/ReaderUITests/ThemeReaderTests.swift` (the suites `NoteFaceTests`, `AISummaryTests`, `NoteActionTests`), `Tests/ReaderUITests/NoteTextHandleTests.swift`

- [ ] **Step 1: Make a table** in the PR text of each N3, N4 and N5 UI test and where it went: moved (with the new harness parameter `initialNoteOpen: true` instead of `initialThemeFace: .note`), replaced by a test of the same property, or removed because the thing is gone (the face switch, the top bar buttons, the 「原文｜AI要約」 switch, the 「原文を見る」 link). Each kept property gets a test: the chosen article is shown after opening the note (was "the article chosen on the note face is the one the articles face shows"), a shown article that left the theme does not break the panel, the note's selection survives closing and reopening the note, the bar is hidden with AI off, the over-limit refusal, the card is dropped on a moved cursor or typing, undo after adopt.
- [ ] **Step 2: Run each test alone. Step 3: Commit** (`test: the note face tests now run against the inspector (L1)`).

### Task 5: Keys, the toolbar, and a real window

**Files:**
- Modify: `Sources/RSSReader/ReaderView.swift`, `Sources/RSSReader/ReaderKeyboardCommands.swift` if needed
- Test: `Tests/ReaderUITests/ThemeReaderTests.swift`

- [ ] **Step 1: Write the failing tests.** The responder rule (an editable note is text input; the list is not) keeps `j` / `k` and the other keys for the list with the note open; the chevron buttons move to the previous and next article and are disabled at the ends and with an empty theme; `⌥⌘I` and `⌥⌘↑` / `⌥⌘↓` do nothing while marked text is present (pure rule test, as in N3); the toolbar button's state follows the note's open state.
- [ ] **Step 2: Implement. Step 3: Run the whole suite and each new test alone.**
- [ ] **Step 4: Exercise a synthetic instance** (own data directory, `open -n`; confirm it is the synthetic one first, AGENTS.md; a separate-bundle-ID copy is fine). If computer use is not allowed, say so and list what stays unchecked. Look at: the inspector's width and resizing, the narrow window (960), the folding sidebar, the toolbar height, the goal strip, and the note's cursor when opening and closing.
- [ ] **Step 5: Commit** (`feat: keys and the toolbar for the note inspector (L1)`).

### Task 6: Documents, verification, review

**Files:**
- Modify: `docs/specification.md` (the screen table, §3.3, §5.1), `docs/architecture.md` (the layout, the open state, the removal of the face), both user guides, `README.md` if it describes the screen; create `docs/verification/2026-10-10-note-inspector.md`.

- [ ] **Step 1:** Update the documents so that they describe the new screen and no longer mention the face switch, the top bar or the 「原文｜AI要約」 switch. **Step 2:** `git diff --check`; the whole suite; the release build.
- [ ] **Step 3: One independent review** of a fixed commit with `docs/review-checklist.md` and the Review Focus above. Fix Critical and Important findings test-first in one pass.
- [ ] **Step 4:** Push the branch and open the PR (English), with the table of moved tests, what it does not include, and the unverified list.

## Unverified after this PR (stated in the PR)

- How the inspector behaves in a real window: the width, resizing, a narrow window, the folding sidebar together with the inspector, the toolbar height, and `⌥⌘I`. Real Japanese IME in the note, VoiceOver, Reduce Motion, macOS 27.0 support floor, macOS 26 CI.
- That every UI test runs in a whole run (the known infrastructure problem).

## Not in this PR

The styled display (L2), the review experiment and panel (L3, L4), the system Writing Tools (L5), the hand-off with the note (N6), the editor scale (PR 10), and the removal of the unreachable question code (N2b).
