# S2 Send a summary to a note: Implementation Plan

> **For agentic workers:** use superpowers:executing-plans (inline). Delete this file in the PR that completes S2 ([roadmap](../../roadmap.md)).

**Goal:** One button on every article, 「ノートに要約を送る」 (key `n`), sends the article's summary (made on the device, or just the title, URL and feed summary) to a new or recent note, links the article to that note, and can be undone ([decision 0019](../../decisions/0019-v1-simplification-notes.md) points 3, 5, 6, 11).

**Architecture:** Pure text rules and settings in ReaderCore with tests first; one atomic store method writes the note text and the article link in a single save; a small `@MainActor` state machine (`SummarySender`) runs one send at a time, bound to the article and the target chosen at the press; the views are thin (a popover list, a status bar, a Settings tab).

**Tech stack:** Swift 6.4, SwiftUI/AppKit, SwiftData, Swift Testing, FoundationModels (behind `TextGenerator`). No new dependency.

**Spec:** [specification.md](../../specification.md) §3.2, §5.1; decision 0019.

## Global Constraints

- macOS floor 27.0 (support) and 26.6 (build). No API that needs the macOS 27 SDK.
- Every mutating `ReaderStore` method calls `reloadIfNeeded()` first and has a save/reload failure-injection test. A failed save is never shown as success.
- AI runs on the device only; no network, no asset download (decision 0009). The AI path never writes anything the person did not press a button for. AI text is always marked 「（AI要約）」.
- English commits and PR text; UI labels stay Japanese. Tests use synthetic data; each UI suite runs alone.
- One independent review of a fixed commit (risky: it writes the person's note) and one verification record, `docs/verification/s2-send-summary.md`.

## Decisions for the PdM (merging this plan approves them)

1. **One send at a time.** While a summary is being made, the menu entry is disabled and the status bar offers 「中止」. A request is tied to the article and the note chosen when the button was pressed; reading on or moving to another article never changes it.
2. **The menu** (a popover from the toolbar icon or `n`): 「新しいノート」 first, then the 8 most recently edited notes by title. ↑/↓ move, Return sends, Esc closes. The picker, `t` and the theme-era `NotePicker` are removed.
3. **New note text:** `# {article title}`, a blank line, the summary, the source line. **Existing note:** a blank line, the summary, the source line, at the end. The source line is `出典: タイトル <URL>`; when the AI wrote the summary it ends with 「（AI要約）」. Sending the same article to the same note again appends again; the link is kept once.
4. **Without AI** (switched off in Settings, or the model is unavailable, or the article body has expired): the block is the feed summary (if there is one) and the source line, no mark. If AI was wanted but is unavailable, the status bar says what was sent instead (「AIが使えないため、タイトルとURLだけ送りました」 and so on).
5. **Undo 「取り消す」** is on the result message for 8 seconds. It works only while the note text is exactly what the send produced; it restores the earlier text, removes the article link only if this send created it, and deletes the note only if this send created it. Otherwise the message says it cannot be undone because the note changed. After the 8 seconds, ⌘Z in the editor and ordinary editing apply.
6. **Settings, tab 「要約」** (the 「端末内AI」 tab becomes this): the existing switch 「AIで要約する（この Mac の中だけ）」, 長さ（1文／3文以内／5文以内、既定は3文以内）, 形式（文章／箇条書き、既定は文章）, and 追加の指示 (optional, 200 characters at most, one line, the person's own words). A bulleted summary is stored as Markdown list lines (`- `).
7. **Linking is by sending only.** Right-click an article in a note's list, 「このノートから外す」, removes the record, with no confirmation, and never changes the note's text, the Star or the article.
8. The empty-state text of a note's list says 「記事を選んで n キーで要約を送ると、ここに並びます。」

## Review Focus (checked deliberately in the review)

1. The text and the link are written in **one save**: a failed save or reload leaves neither; undo never removes more than the send made, and refuses when the note changed.
2. AI text never lands unmarked; the extra instruction cannot exceed 200 characters, cannot carry a line break into the instructions, and article text never reaches the instructions.
3. A late or cancelled result, an answer for another article, a note deleted meanwhile, the AI switched off while the request runs: nothing is written.
4. Key `n`: not while typing in a field or the note, not during Japanese composition, not while a sheet is open; works in the original-page view like `s`.
5. Hostile article text (marker-like lines, 1 MB of text, empty body, no URL, CRLF in the target note) and a very long note: the append stays correct and fast.

---

### Task 1: The block and the new note text (pure, test first)

**Files:** modify `Sources/ReaderCore/NoteInsertion.swift` (`summaryBlock(summary:title:url:aiMade:)`; `newNoteText(title:block:)`; `appended(block:to:)`), `Tests/ReaderCoreTests/NoteInsertionTests.swift`.

- [ ] **Step 1 (RED):** tests for: the AI mark on the source line only when `aiMade`; no summary line when the summary is empty (source line only); no source line when there is neither title nor URL; a title with line breaks folded to one line; the new-note text `# title\n\nsummary\nsource\n` (a title of only marks or spaces falls back to 「無題の記事」); the append to an empty note, a note ending without a line break, with one, with two, and a CRLF note (CRLF kept); a 100,000-line note appended in one pass. Run `swift test --filter NoteInsertionTests`. Expected: FAIL (compile).
- [ ] **Step 2 (GREEN):** implement. Expected: PASS. Commit `feat: the summary block with the AI mark, and the new-note text (S2)`.

### Task 2: Summary settings and the prompt (pure, test first)

**Files:** create `Sources/ReaderCore/SummarySettings.swift` (`SummaryLength`, `SummaryFormat`, the stored values and their `UserDefaults` keys, clamping, the 200-character one-line instruction), modify `ArticleSummaryPrompt.swift` (`make(title:text:settings:)`, `clean(_:format:)`), tests `SummarySettingsTests`, `ArticleSummaryPromptTests`.

- [ ] **Step 1 (RED):** the defaults (3 sentences, prose, no extra instruction); a missing, wrong-type or unknown stored value falls back to the default; the extra instruction is trimmed, folded to one line and cut at 200 characters by `Character` (an emoji or a combining mark is never split); it goes into the instructions after the fixed rules, labelled as the person's words, and the article text never enters the instructions; the length words (1文/3文/5文) appear; the bullets format asks for lines and `clean` turns them into `- ` lines, drops empty lines, keeps at most 1,200 characters; the prose format keeps the old behavior.
- [ ] **Step 2 (GREEN):** implement; run `--filter 'SummarySettingsTests|ArticleSummaryPromptTests'`. Commit.

### Task 3: One atomic send and its undo (store, test first)

**Files:** modify `Sources/ReaderCore/Notes.swift` (`sendArticle(_:to:block:newNoteTitle:at:)` returns `SendResult` with the note ID, the text before and after, whether the send created the note and the link; `undoSend(_:at:)`), tests `NoteTests`, `ReaderStoreTests` (failure injection list).

- [ ] **Step 1 (RED):** sending to a new note makes the note and the link in one save; to an existing note appends and links once (a second send appends again, one link); a failed save leaves no note, no link and the old text (and a failed reload after a save is reported, never as success); an unknown note or article throws and changes nothing; undo restores the text, removes a link the send created and deletes a note the send created; undo refuses (returns false, changes nothing) when the note text changed since; a link that already existed is kept by undo; `sendArticle` and `undoSend` are in the "blocked until reload succeeds" list.
- [ ] **Step 2 (GREEN):** implement (`reloadIfNeeded()` first, one `save()`); run `--filter 'NoteTests|ReaderStoreTests'`. Commit.

### Task 4: `SummarySender` (state machine, test first)

**Files:** create `Sources/ReaderCore/SummarySender.swift` (replaces the UI-facing use of `ArticleSummaryModel`; reuse its prompt, deadline and cleaning; delete `ArticleSummaryModel` and its tests if nothing else uses them), tests `SummarySenderTests` using `FakeGenerator`.

- [ ] **Step 1 (RED):** with AI: a send writes the marked block and the link, state `done`; a second `start` while working is refused; `cancel` writes nothing; a late answer after cancel or after another start is dropped; a note deleted while working fails with 「ノートが見つかりません」 and writes nothing; the AI switch turned off while working: nothing written (read again at the answer); model unavailable, assets missing, guardrail refusal, a 20-second deadline, an empty or blank answer: the non-AI block is sent and the message says so; AI off: the non-AI block, no mark, the model is never called; an expired body: the RSS summary or the title and URL; undo works once and only while unchanged; the result carries what the message needs (note title, whether AI wrote it).
- [ ] **Step 2 (GREEN):** implement; run `--filter SummarySenderTests`. Commit.

### Task 5: The screens

**Files:** create `Sources/RSSReader/SendToNoteView.swift` (the popover), `Sources/RSSReader/SendStatusBar.swift`, `Sources/RSSReader/SummarySettingsView.swift`; modify `ReaderView.swift` (toolbar icon 「ノートに要約を送る」, key `n`, the status bar overlay, the removal context menu, the empty-state text), `ReaderKeyboardCommands.swift` (`sendToNote = "n"`; the original-page bridge allows it), `NativeArticleList.swift` (a row context menu hook), `ReaderSettingsView.swift` (tab 「要約」), `RSSReaderApp.swift`; delete `NotePickerView.swift`, `NotePicker.swift`, `NotePickerTests.swift`.

- [ ] **Step 1 (RED):** UI tests (each suite alone): the toolbar button is enabled with an article shown and disabled without one; `n` opens the menu and `t` does nothing; the menu lists 「新しいノート」 and at most 8 notes newest edit first; Return on 「新しいノート」 with a fake generator creates the note and shows the status bar with 「取り消す」; 「取り消す」 puts everything back; removing a link from the list leaves the note text; the settings tab has the switch, the two choices and the field. The keyboard rules: no `n` handling while a field is edited or marked text exists or a sheet is open.
- [ ] **Step 2 (GREEN):** implement; run each UI suite alone. Commit.

### Task 6: Documents, record, review, PR

- [ ] **Step 1:** update the specification header (S2 done), architecture §3, both user guides (the key `n`, the menu, the settings, undo; remove `t` and the picker), the README keys line if present, the roadmap (S2 done), delete this plan.
- [ ] **Step 2:** create `docs/verification/s2-send-summary.md` (result in the first three lines; a table of what ran; what is not verified: the real model on real articles, a real window, Japanese input, VoiceOver, macOS 26 CI).
- [ ] **Step 3:** whole suite, each UI suite alone, `bash scripts/build-app.sh release`, `git diff --check`; a short real-window check on a copy of the app with its own bundle identifier and synthetic data; one independent review with the Review Focus; one fix pass.
- [ ] **Step 4:** push `claude/s2-send-summary` and open the PR (English; not included: the Claude share button (S3), clean-up (S4), editor styling (S5)).
