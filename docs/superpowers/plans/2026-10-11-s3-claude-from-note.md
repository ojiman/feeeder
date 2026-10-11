# S3 Claude from the note: Implementation Plan

> **For agentic workers:** use superpowers:executing-plans (inline). Delete this file in the PR that completes S3 ([roadmap](../../roadmap.md)).

**Goal:** When a note's panel is shown, a share-style button in its header offers 「Claudeで開く…」, 「Markdownをコピー」 and 「Markdownとして書き出す…」. The Claude entry shows the note's full text and the request, and opens Claude Desktop only after the person presses the button ([decision 0019](../../decisions/0019-v1-simplification-notes.md) point 8; the review screen and the managed copies keep [decision 0012](../../decisions/0012-claude-handoff-from-themes.md)).

**Architecture:** The package code already builds a package of the note alone (no sources, 24 hours, invalid after an edit). S3 changes what the person sees and starts: a menu in the panel header, a simpler review screen that always builds from the note only, and two small pure helpers for the Markdown file. The article hand-off entry and the source list are removed from the screens; the unused source code is removed in S4.

**Tech stack:** Swift 6.4, SwiftUI/AppKit, Swift Testing. No new dependency.

**Spec:** [specification.md](../../specification.md) §5.2, PRD-05; decision 0019 point 8.

## Global Constraints

- macOS floor 27.0 (support) and 26.6 (build). No API that needs the macOS 27 SDK.
- What leaves the Mac is exactly what the screen shows: the review text, the copied text, the exported file and the file Claude receives are the same bytes. Nothing leaves before the person presses a button. The real launch of Claude Desktop is never pressed in tests (a fake launcher is used).
- A failed save, copy or launch is never shown as success. English commits and PR text; UI labels stay Japanese. Tests use synthetic data; each UI suite runs alone.
- One independent review of a fixed commit (an external write) and one verification record, `docs/verification/s3-claude-from-note.md`.

## Decisions for the PdM (merging this plan approves them)

1. **The button** is the system share icon (`square.and.arrow.up`) at the right of the panel header, a menu with three items. It is not shown without a note. 「Claudeで開く…」, 「Markdownをコピー」 and 「Markdownとして書き出す…」 are disabled while the note is empty or only white space.
2. **The article hand-off entry is removed:** the paperplane in the toolbar and the button 「Claudeでレビューを頼む」 go. No screen builds a package with articles.
3. **The review screen** keeps its title, the output language (日本語 / English), the full text, the size and expiry, the SHA-256 and the buttons 「全文をコピー」, 「TXTを書き出す」, 「分割を書き出す」 and 「Claudeで開く」; the source list and the 「ノートを含める」 switch are gone, because the note is the whole package. It rebuilds when the language changes.
4. **The request to Claude** asks, for the note: what is already solid (quoting the note); what is missing, judged only from what the note does not say and never claiming that something is missing when the note says it; **opposing views worth checking**; and what to read or write next. It does not ask Claude to rewrite the note or write into the app, and it treats the note's own text as data.
5. **The launch prompt** no longer asks for Source IDs and URLs (a note-only package has none).
6. **Copy** puts the note's exact text on the pasteboard, with no confirmation screen and a short message 「ノートをコピーしました」. **Export** opens the save panel with 「{title}.md」 (the title made safe as a file name: no path separators, no control characters, at most 80 characters); the file is the note's exact bytes (UTF-8, no added line break), written atomically; the panel's own question covers an existing file.
7. `HandoffDefaults` (the note switch) is deleted. System sharing services (Messages, Mail) stay after V1.

## Review Focus (checked deliberately in the review)

1. **The same bytes everywhere:** the text in the review preview, the copied text, the exported TXT and parts, and the file given to Claude are one package; editing the note while the sheet is open makes the review invalid and nothing stale can be copied, exported or opened.
2. **The Markdown export:** file names from hostile titles (`../x`, `a/b`, a title of only dots or spaces, 10,000 characters, emoji and combining marks, NUL); no overwrite without the save panel; a write failure is shown; a 1 MiB+ note and CRLF text are exact.
3. **Empty and white-space notes:** the entries are disabled and no package or file is made; a note emptied while the sheet is open.
4. **No leftover article path:** nothing in the screens builds a package with sources; managed copies made by earlier builds (with article sources or the old key) still reconcile or are removed without a maintenance error.
5. **The request text:** no goal, no source line, the opposing-views item, no instruction that Claude may write into the app; the launch prompt has no Source ID.

---

### Task 1: The request text and the launch prompt (pure, test first)

**Files:** modify `Sources/ReaderCore/AIPackage.swift` (`reviewRequest(hasSources:)` for a note alone), `Sources/ReaderCore/HandoffFiles.swift` (`ClaudeLink.prompt`), tests `AIPackageTests`, `ClaudeHandoffTests`.

- [ ] **Step 1 (RED):** a package of the note alone contains the four items (solid with quotes, missing only from what the note does not say, opposing views worth checking, what to read or write next), the line that tells Claude not to rewrite the note or write into the app, and no mention of sources, goal or `Source ID`; with sources (still built by old code) the earlier request stays; `ClaudeLink.prompt` has no 「Source ID」 and still asks to read the whole attached package and not to guess. Run `swift test --filter 'AIPackageTests|ClaudeHandoffTests'`. Expected: FAIL.
- [ ] **Step 2 (GREEN):** change the texts. Expected: PASS. Commit `feat: the review request for a note alone asks for opposing views; the launch prompt has no Source ID (S3)`.

### Task 2: The Markdown file helpers (pure, test first)

**Files:** create `Sources/ReaderCore/NoteMarkdown.swift` (`fileName(forTitle:)`, `data(for:)`), `Tests/ReaderCoreTests/NoteMarkdownTests.swift`.

- [ ] **Step 1 (RED):** `fileName`: 「金利の話」 gives 「金利の話.md」; `a/b` and `a:b` and `..` and NUL and tabs are replaced with a space and folded; leading dots and spaces are removed; a title of only dots, spaces or marks falls back to 「ノート.md」; 10,000 characters are cut to 80 by `Character` (an emoji or a combining mark is never split) before `.md`; `data(for:)` is the exact UTF-8 bytes of the text (CRLF, emoji, a 1 MiB+ text, an empty text gives empty data) with no BOM and no added line break.
- [ ] **Step 2 (GREEN):** implement; run `--filter NoteMarkdownTests`. Commit.

### Task 3: The screens

**Files:** modify `Sources/RSSReader/NotePanel.swift` (the share menu in place of the button; closures `onClaude`, `onCopy`, `onExport`; disabled while the note is blank), `ReaderView.swift` (remove the toolbar paperplane, `canAskReview`, `claudeSelections`, `NoteSheet.fromNotePanel`; the copy and export actions with a 2-second message; the sheet opens from the menu), `AIReviewView.swift` (note only: remove the source list, the switch and the options code; build with no selections and `includeNote: true`), `HandoffDefaults.swift` and `HandoffDefaultsTests.swift` (delete); tests `NoteReaderTests` (`HandoffEntryTests` is rewritten).

- [ ] **Step 1 (RED):** UI tests, each suite alone: the panel header has one share button and no 「Claudeでレビューを頼む」 or toolbar paperplane; with text it offers three enabled items, with a blank note all three are disabled; 「Claudeで開く…」 opens the sheet whose package text holds the note verbatim, the request, no `BEGIN_SOURCE` and no goal; editing the note while the sheet is open makes the sheet ask to rebuild and copy fails; 「Markdownをコピー」 puts the exact text on a private pasteboard (injected, never the general one); the export writes the exact bytes to a temporary file through an injected save step, and a failing write shows an error. Expected: FAIL.
- [ ] **Step 2 (GREEN):** implement; run each UI suite alone. Commit.

### Task 4: Documents, record, review, PR

- [ ] **Step 1:** update the specification header (S3 done), architecture §3.2, both user guides (the share button, the three items, the review screen without sources, what leaves the Mac), the README, the roadmap (S3 done), and delete this plan.
- [ ] **Step 2:** create `docs/verification/s3-claude-from-note.md` (result in the first three lines; what ran; not verified: a real launch of Claude Desktop with a note, the usefulness of Claude's review, a very large note through Cowork, Japanese input, VoiceOver, macOS 26 CI).
- [ ] **Step 3:** whole suite, each UI suite alone, `bash scripts/build-app.sh release`, `git diff --check`; a short real-window check on a copy with its own bundle identifier and synthetic data (do not press the real launch button); one independent review with the Review Focus; one fix pass.
- [ ] **Step 4:** push `claude/s3-claude-from-note` and open the PR (English; not included: S4 clean-up of the source code, S5 styling, system sharing services).
