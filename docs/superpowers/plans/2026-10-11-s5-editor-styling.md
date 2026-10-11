# S5 Light styling of headings and lists: Implementation Plan

> **For agentic workers:** use superpowers:executing-plans (inline). Delete this file in the PR that completes S5 ([roadmap](../../roadmap.md)).

**Goal:** The note editor shows `#` headings and list lines in a calmer, more readable way (bigger bold headings, orange list markers, a hanging indent) while **the saved text stays byte for byte what the person typed** ([decision 0019](../../decisions/0019-v1-simplification-notes.md) point 4; the vision's "smooth feel").

**Architecture:** A pure scanner finds the heading and list lines of a text (UTF-16 ranges, tested first). A small AppKit editor (`NSViewRepresentable` over `NSTextView`) replaces SwiftUI's `TextEditor`: its text storage delegate sets display attributes only (font, colour, paragraph indent) on the edited paragraphs, and never while Japanese text is being composed. The note is saved through the same path as today (`saveNote` on every change).

**Tech stack:** Swift 6.4, AppKit (needed: SwiftUI's `TextEditor` gives no hook for display attributes of plain text), SwiftUI, Swift Testing. No new dependency.

**Spec:** [specification.md](../../specification.md) §3.3; decision 0019 point 4.

## What a spike showed (2026-10-11, a throwaway test on a headless `NSTextView`; not committed)

| Question | Result |
|---|---|
| Attributes set by a `NSTextStorageDelegate` change the text? | No. `string` stayed identical (CRLF, emoji, combining marks). |
| Composition (marked text) | While `hasMarkedText()` the delegate does nothing; after the commit the next edit pass styles the paragraph (`# にほん` marked, `# 日本` committed, heading font applied). |
| Undo and redo | Work with a window; attribute-only passes added nothing to the undo stack; the styling is still there after a redo. |
| Selection | Unchanged by a styling pass. |
| A 60,000-line note | Setting the whole text and styling it took about 0.13 s; 50 keystrokes in it took about 7 ms (only the edited paragraph is restyled). |

Not shown by the spike (and not shown by any headless test): real Japanese input methods, the caret and the candidate window in a real window, VoiceOver.

## Global Constraints

- macOS floor 27.0 (support) and 26.6 (build). No API that needs the macOS 27 SDK.
- The note is saved as typed: no automatic quote, dash, text replacement or link substitution; no list auto-continuation; no change of the text by styling. The title rule (`NoteTitle`) and the saved text are unchanged.
- A failed save is never shown as success (the error alert stays). Composition must never be disturbed. English commits and PR text; UI labels stay Japanese. Tests use synthetic data; each UI suite runs alone.
- Risky for the person's writing: one independent review of a fixed commit and one verification record, `docs/verification/s5-editor-styling.md`.

## Decisions for the PdM (merging this plan approves them)

1. **What is styled (V1):** headings `#` to `######` followed by a space (or alone on the line): bold, level 1 about 1.5x, level 2 about 1.3x, level 3 about 1.15x, levels 4 to 6 bold at body size; the `#` marks stay in the text and are drawn in the secondary colour. List lines `- `, `* `, `+ `, `1. ` and `1) ` (after up to 8 leading spaces): the marker in the accent colour and a hanging indent so wrapped lines align with the text after the marker; each 2 leading spaces indent one more step. Everything else is plain. **Not styled:** bold or italic marks, code, links, quotes, tables, check boxes (`- [ ]` is a list line).
2. **Display only.** The Return key does not continue a list, and no Markdown is rewritten. (A list auto-continuation is a candidate for after V1.)
3. **The editor is replaced by an AppKit one** that keeps today's behaviour: the same background and padding, the placeholder text for an empty note, the accessibility label 「ノート」, no focus taken at launch, the save-error alert, undo and redo, the system spelling check and the system find. Smart quote, dash and replacement substitution and link detection are **off**, so what is typed is what is stored.
4. **Fonts and colours** are the system body font and semantic colours (light and dark follow the system). The editor's size stays what it is today (the reading-size candidate PR comes later).
5. If the real Japanese input check by the PdM finds a problem, S5 is reverted whole (one PR); it does not block the beta.

## Review Focus (checked deliberately in the review)

1. **The text is never changed by the editor:** typing, paste (plain text only; rich text pasted from another app becomes plain text), drop, undo and redo, an external change (a summary sent by `n` and its undo), a note switch; CRLF, emoji, combining marks, U+2028; a 1 MiB+ note.
2. **Composition:** no attribute change on the marked range while composing; the paragraph is styled after the commit and after a cancel (Esc, delete) and after the selection leaves; a stuck, unstyled heading is the failure to look for. The binding must not overwrite the view while marked text exists.
3. **Selection and scroll:** the caret and the selection keep their place when text arrives from outside; the scroll position of a long note is kept on a note switch back.
4. **Saving:** every change reaches `saveNote` once (not once per attribute pass); a failed save shows the alert and the typed text stays in the view; the sidebar title follows the first line.
5. **Speed:** a 60,000-line note loads and styles within 0.5 s and a keystroke costs a paragraph, not the note.

---

### Task 1: The line scanner (pure, test first)

**Files:** create `Sources/ReaderCore/NoteLineStyle.swift` (`NoteLineStyle.runs(in:) -> [Run]`; `Run` has a UTF-16 range for the line, its kind (`heading(level)`, `listItem(indent, ordered)`), and the marker range), `Tests/ReaderCoreTests/NoteLineStyleTests.swift`.

- [ ] **Step 1 (RED):** `# a` is level 1, `###### a` level 6, `####### a` (7 marks) and `#a` and `#` followed by a tab are not headings (a lone `#` line is a level 1 heading); `- a`, `* a`, `+ a`, `1. a`, `12) a` are list items, `-a` and `1.a` and `--- ` are not (a rule line); up to 8 leading spaces count as indent (2 spaces per step); nine are plain; CRLF, CR and U+2028 end lines; ranges are in UTF-16 units and correct after emoji and combining marks; an empty text and a text without a final line break; a line of 100,000 characters; the whole 60,000-line note in under 0.5 s. Run `swift test --filter NoteLineStyleTests`. Expected: FAIL.
- [ ] **Step 2 (GREEN):** implement (one pass, no regular expression on the whole text). Expected: PASS. Commit `feat: find the heading and list lines of a note (S5)`.

### Task 2: The AppKit editor

**Files:** create `Sources/RSSReader/NoteTextEditor.swift` (the `NSViewRepresentable`, a coordinator that is the text view's delegate and the storage delegate, the styling pass, the marked-text rule), `Sources/RSSReader/NoteEditorStyle.swift` (the fonts, colours and paragraph styles per kind); tests `Tests/ReaderUITests/NoteTextEditorTests.swift`.

- [ ] **Step 1 (RED):** hosted in a window: the view's string equals the stored text after load (with CRLF, emoji, a 100,000-line text); typing through `insertText` reaches `saveNote` once per change; a heading line gets the bold larger font and its marks the secondary colour, a list line gets the accent colour on its marker and a hanging indent, and the string is unchanged; `setMarkedText` on a heading line leaves its attributes alone and the committed text is styled after `insertText`; a cancelled composition (`unmarkText` after `setMarkedText`, and deleting the marked range) leaves no unstyled stuck line; undo and redo restore the text and the styling; an outside change of the stored text (a send and its undo) updates the view, keeps the selection inside the text and does nothing while marked text exists; pasting rich text from a private pasteboard inserts plain text; the editor does not become first responder on its own; smart substitutions are off.
- [ ] **Step 2 (GREEN):** implement; run `--filter NoteTextEditorTests` alone. Commit.

### Task 3: Put it in the panel

**Files:** modify `Sources/RSSReader/NoteEditor.swift` (use `NoteTextEditor`; keep the placeholder, the background, the padding, the accessibility label and the error alert); tests `NoteReaderTests`, `NotePanelTests` stay green.

- [ ] **Step 1 (RED):** a UI test that the panel's editor is the new one (an `NSTextView` with the note's text), that typing a line `# 見出し` in it moves the sidebar title, and that the placeholder shows for an empty note and disappears after the first character.
- [ ] **Step 2 (GREEN):** wire it; run each UI suite alone. Commit.

### Task 4: Documents, record, review, PR

- [ ] **Step 1:** update the specification header (S5 done) and §3.3, architecture §6 (the editor), both user guides (what is styled, that the text is unchanged, no list continuation), the roadmap (S5 done), and delete this plan.
- [ ] **Step 2:** create `docs/verification/s5-editor-styling.md` (result in the first three lines; what ran; not verified: a real Japanese input method with candidates and the caret, VoiceOver, a very long note in a real window, macOS 26 CI).
- [ ] **Step 3:** whole suite, each UI suite alone, `bash scripts/build-app.sh release`, `git diff --check`; a short real-window check on a copy with its own bundle identifier and synthetic data (type a heading and a list with the accessibility text input, scroll a long note); one independent review with the Review Focus; one fix pass.
- [ ] **Step 4:** push `claude/s5-editor-styling` and open the PR (English; not included: bold/italic/code styling, list continuation, check boxes, the editor size setting).
