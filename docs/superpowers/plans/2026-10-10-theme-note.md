# N2: The note, and the migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This project keeps one supervised implementer ([decision 0002](../../decisions/0002-single-supervised-writer.md)).

**Goal:** Each theme gets one plain-text note. The questions face becomes the note face. The first time the new version opens a library, everything the person wrote in a theme (the "current understanding", every question, answer, and evidence list) is turned into note text, and only then are the old records removed. Nothing the person wrote is lost.

**Architecture:** One new stored field, `Theme.note`, saved on every change like the current understanding. One pure function composes the legacy text (`LegacyNoteText`). One store function (`migrateLegacyThemeContent`) writes all notes and removes all legacy content **in a single save**, so it either happens completely or not at all, and it verifies the result before it saves. The app calls it at launch, outside the "library could not be opened" path. The question screens are removed from the UI. The old model classes and the store code that is no longer reachable stay for now (see decision 3 below).

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing. No new dependency.

**Spec:** [decision 0013](../../decisions/0013-goal-and-note-for-themes.md) (points 2, 3, 4), [roadmap Part 1c, row N2](2026-10-10-theme-notes.md), PRD §3.2, §3.3, PRD-04, PRD-06, PRD-13. Merging this plan approves it. Plan approval is not product acceptance.

**Language:** New project text is in English (AGENTS.md, "Language"). App labels stay Japanese; they are quoted as they appear, with a short English gloss.

## Decisions for you (merging approves them)

1. **What the migrated note looks like.** For each theme, in this order, separated by one blank line:
   - the old "current understanding" text as it is (no heading), if it is not blank;
   - then, for each question in creation order: a heading line `# <question>`, then the answer exactly as typed (if not blank), then, if the question had evidence, the line `根拠の記事:` (the label "Evidence articles:") and one list line `- <title> <<url>>` per article (just `- <title>` when it has no link).
   A question with line breaks puts its first line in the heading and the rest right under it. An unanswered question stays as a heading with nothing under it. A theme with nothing to convert gets no note. If a note already has text, the legacy text goes **after** it, never over it.
2. **What does not carry over.** The lens (the name of the fixed angle such as 「前提を疑う」), the "answered" mark, and the question timestamps. They are labels the app made, not words the person wrote; the lens text is already part of the question for the fixed lenses. I will say so in the user guide and in the PR.
3. **The old model stays in the schema for now.** `ThemeQuestion` and `Theme.understanding` stay as stored fields until a later cleanup, because a library that has not been migrated yet (for example after a failed migration) must still open and be readable by the next attempt. Removing a model class from the schema would drop its table. The question store functions, the question proposal in the AI code, and their tests are no longer reachable from the screen after this PR; I remove them in a follow-up deletion PR ("N2b") after you have seen the migration work on your own library. Removing the model classes is a separate step before 1.0 (the schema freeze).
4. **The Claude hand-off is paused between N2 and N6.** After the migration there are no questions, so the hand-off has no theme context to send (the articles still go). The review screen says so in plain words: 「テーマのノートはまだ Claude へ渡せません。」 ("The theme's note can not be handed to Claude yet."). N6 adds the goal and the note (note off by default, decision 0013 point 7).
5. **A temporary layout until N3.** On the note face: the note is in the middle column (its final place), and the right column keeps showing the article that was selected on the articles face, so you can read while you write. There are no previous / next buttons and no `j` / `k` on the note face, and the sidebar does not fold. N3 adds those. If the reader on the right does not load an article correctly without further work, I show a short hint instead (「記事は［記事］に切り替えて読みます」, "Switch to Articles to read") and record that as a ruling.
6. **Migration runs by itself at launch, and tells you.** It runs once, before the window shows the library. A failure does not stop the app: an alert says the old content was **not** touched and offers "retry"; the next launch tries again. A success shows one alert (「問いと答えをノートにまとめました（N件のテーマ）」, "Moved questions and answers into notes (N themes)") so you know where they went. **Please copy the whole `Feeeder` data folder before the first launch** (the user guide's backup steps); the app does not make its own copy.
7. **The note has no length limit and is saved on every change**, the same way the current understanding is. Very long notes are not measured yet; the note editor's scale is PR 10. I add a timing test that only records the time for a 100,000-character note.

## Global Constraints

- Support floor macOS 27.0; build floor and CI stay macOS 26.6 / Swift 6.3.3. No macOS 27-only API.
- Every store function that writes starts with `reloadIfNeeded()`. Its failure paths are in the failure-injection lists (`failedSaveLeavesNoPartialThemeStateAndCanBeRetried`, `eachThemeChangeRecoversOnItsFirstCallAfterReloadSucceeds`). A failed save is never shown as success; text the person typed is never dropped silently (AGENTS.md, Definition of done 7).
- The migration must not delete anything unless the composed note was verified and the one save succeeded. Do not delete an unreadable store (AGENTS.md, Data policy).
- No `Binding` setter that is a method reference; no mutated captured `var` in `@MainActor` closures in tests (Swift 6.3.3 on CI fails on both).
- Tests use synthetic data and temporary databases only. Do not read the person's library. The real library is touched only by the person's own launch.
- One theme per PR. Failing tests first. Commit and PR text in English. Add the attribution line the session gives.
- The specification, architecture and both user guides are updated in the same PR, with a decision record (AGENTS.md, Definition of done 6). Do not push to `main`, sign, or release. After implementation and one independent review of a fixed commit (store, model, deletion), push the branch and open the PR without asking (standing instruction).

## Review Focus

1. A theme with only an understanding; only questions; both; neither; blank (spaces and line breaks only) understanding or answers → Task 2, Task 3.
2. Question text with line breaks or starting with `#`; answers with their own `#` lines, with CRLF, with trailing spaces → Task 2.
3. Evidence for an article that left the theme, an article with no link, a title with a line break → Task 2, Task 3.
4. The save fails (and the reload after it fails): nothing changes, the old content is still there, and a retry works → Task 3.
5. The migration runs twice, and runs when the note already has text → Task 3.
6. A review or a managed Claude copy that was built from the old questions is invalidated after the migration → Task 3.
7. The note is typed while its theme is deleted: an error is shown, the text is not dropped silently → Task 1, Task 5.
8. A very long note: saving and typing stay usable (recorded, not gated) → Task 1.

---

### Task 1: The note field and its save path

**Files:**
- Modify: `Sources/ReaderCore/Themes.swift`
- Test: `Tests/ReaderCoreTests/ThemeTests.swift`

**Interfaces:**
- Consumes: `ReaderStore.reloadIfNeeded()`, `save()`, `theme(id:)`.
- Produces: `Theme.note: String` (default `""`), `ReaderStore.saveNote(themeID:text:at:)` (typing path: saves without reloading, text stored exactly as typed, throws `ThemeError.missingTheme` when the theme is gone).

- [ ] **Step 1: Write the failing tests** (add to `ThemeTests`; `at`, `TestLibrary`, `gatedStore`, `SaveGate` exist)

```swift
    @Test func aNoteIsStoredExactlyAsTypedAndKeptAfterReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let text = "# 見出し\r\n  本文の行  \n\n- 箇条書き\n"
        let themeID = try {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let theme = try store.createTheme(name: "Note", at: at)
            try store.saveNote(themeID: theme.id, text: text, at: at.addingTimeInterval(3))
            #expect(theme.note == text && theme.updatedAt == at.addingTimeInterval(3))
            let stamp = theme.updatedAt
            try store.saveNote(themeID: theme.id, text: text, at: at.addingTimeInterval(9))      // no change, no new stamp
            #expect(theme.updatedAt == stamp)
            return theme.id
        }()
        #expect(try ReaderStore(url: library.url, now: at).theme(id: themeID)?.note == text)
    }

    @Test func savingANoteForAMissingThemeIsAnErrorNotASilentDrop() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        #expect(throws: ThemeError.self) { try store.saveNote(themeID: UUID(), text: "書いたこと", at: at) }
        let theme = try store.createTheme(name: "Gone", at: at)
        try store.deleteTheme(id: theme.id)
        #expect(throws: ThemeError.self) { try store.saveNote(themeID: theme.id, text: "消えたテーマへ", at: at) }
    }

    @Test func aLongNoteSavesAndItsTimeIsRecorded() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "Long", at: at)
        let long = String(repeating: "長いノートの一行です。\n", count: 10_000)                 // about 100,000 characters
        let start = ContinuousClock.now
        try store.saveNote(themeID: theme.id, text: long, at: at)
        print("note-save 100k characters:", ContinuousClock.now - start)                       // recorded in the verification file, not a gate
        #expect(theme.note.count == long.count)
    }
```

Add the failure injection next to the existing `saveUnderstanding` lines of the two lists:

```swift
        // failedSaveLeavesNoPartialThemeStateAndCanBeRetried
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.saveNote(themeID: theme.id, text: "失われるノート", at: at) }
        #expect(store.theme(id: theme.id)?.note == "")
        try store.saveNote(themeID: theme.id, text: "再試行のノート", at: at)
        #expect(store.theme(id: theme.id)?.note == "再試行のノート")
```

```swift
        // eachThemeChangeRecoversOnItsFirstCallAfterReloadSucceeds
        induceFailedRecovery()
        try store.saveNote(themeID: themeID, text: "回復後のノート", at: at)
        #expect(store.theme(id: themeID)?.note == "回復後のノート")
```

(Read the surrounding code first. If a local name differs, use the existing one. In the recovery test, put the new lines after the last exact-list check.)

- [ ] **Step 2: Run and see them fail.** `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests` → compile errors (`note`, `saveNote` do not exist).
- [ ] **Step 3: Implement.** In `Theme`: `public var note: String = ""` (a defaulted new field: a lightweight SwiftData change; older stores open with empty notes). In `ReaderStore`:

```swift
    /// Typing path: saves without reloading so the editor is not rebuilt on every change. The text is stored exactly as typed.
    public func saveNote(themeID: UUID, text: String, at: Date) throws {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID) else { throw ThemeError.missingTheme }
        guard theme.note != text else { return }
        theme.note = text; theme.updatedAt = at
        try save()
    }
```

- [ ] **Step 4: Run again.** Expected: the whole `ThemeTests` passes, and the timing line is printed.
- [ ] **Step 5: Commit** (`feat: a note field and its save path for a theme (N2)`).

### Task 2: Composing the legacy text

**Files:**
- Create: `Sources/ReaderCore/LegacyNoteText.swift`
- Test: Create `Tests/ReaderCoreTests/LegacyNoteTextTests.swift`

**Interfaces:**
- Consumes: nothing from the store (pure value logic).
- Produces:

```swift
public enum LegacyNoteText {
    public struct Evidence: Sendable, Equatable { public var title: String; public var url: String? }
    public struct Question: Sendable, Equatable { public var text: String; public var answer: String; public var evidence: [Evidence] }
    /// The note after migration: `existingNote` first, then the understanding, then the questions (decision 0014 format).
    public static func compose(existingNote: String, understanding: String, questions: [Question]) -> String
    /// Every non-blank piece of source text appears in `note`. The migration checks this before it deletes anything.
    public static func containsEverything(_ note: String, understanding: String, questions: [Question]) -> Bool
}
```

- [ ] **Step 1: Write the failing tests.** Each case builds the input and compares the whole output string. Cases (write them as literal strings; the format is decision 1 above):
  - understanding + one answered question with two evidence articles (one without a link) → `"いまの理解\n\n# 問い\n\n答え\n\n根拠の記事:\n- タイトルA <https://example.com/a>\n- タイトルB\n"`.
  - understanding only → the text, ending in one `"\n"`; blank understanding with no questions → `""`.
  - an unanswered question with no evidence → `"# 問い\n"`.
  - a question with line breaks → first line in the heading, the rest right under it, then the answer.
  - a question that starts with `#` → `"# # …"` (kept as typed).
  - an answer with its own `# ` lines, CRLF and trailing spaces → inside the answer, bytes unchanged (only the blank lines at both ends are trimmed).
  - a title with a line break → the break becomes a space in the list line (a list line is one line).
  - an existing note `"既存"` → output starts with `"既存\n\n"`, then the legacy text.
  - blank answers (spaces, line breaks) are treated as no answer; two questions keep the order they were given.
  - `containsEverything` is true for each composed output, and false when one piece is removed from the output (a mutation of the test's own string).
- [ ] **Step 2: Run and see them fail** (`--filter LegacyNoteTextTests`; the type does not exist).
- [ ] **Step 3: Implement.** Sections are joined with exactly one blank line; the output ends with a single `"\n"` unless it is empty. Trim only leading and trailing blank lines of understanding and answers, never characters inside. Heading: first line of the trimmed question text. `containsEverything` checks, for each non-blank understanding, answer, question text line, and evidence title (line breaks as spaces), that `note` contains it.
- [ ] **Step 4: Run again.** Expected: all pass.
- [ ] **Step 5: Commit** (`feat: compose the note text that replaces questions and answers (N2)`).

### Task 3: The migration in the store

**Files:**
- Modify: `Sources/ReaderCore/Themes.swift` (or a new `Sources/ReaderCore/LegacyNoteMigration.swift` if it grows past 60 lines)
- Test: `Tests/ReaderCoreTests/ThemeTests.swift` (failure injection) and a new `Tests/ReaderCoreTests/LegacyNoteMigrationTests.swift`

**Interfaces:**
- Consumes: `LegacyNoteText.compose`, `containsEverything`; `themes`, `questions(themeID:)`, `themeArticles`, `article(id:)`, `save()`, `reload()`, `onContentPolicyChanged`.
- Produces:

```swift
public struct LegacyNoteMigrationResult: Equatable, Sendable { public let themes: Int; public let questions: Int }
public enum LegacyNoteMigrationError: LocalizedError { case verificationFailed(themeName: String) }
extension ReaderStore {
    /// Moves every theme's understanding, questions, answers and evidence into its note, in one save. Nothing is deleted unless the
    /// composed notes contain all of it. A second call finds nothing to do. Calls `onContentPolicyChanged` after questions are removed.
    @discardableResult public func migrateLegacyThemeContent(at: Date) throws -> LegacyNoteMigrationResult
}
```

- [ ] **Step 1: Write the failing tests** (`LegacyNoteMigrationTests`, synthetic stores built with the current question functions; `at`, `TestLibrary`)
  - `migrationMovesEverythingAndRemovesTheOldRecords`: three themes — (A) understanding + two questions (one answered with evidence of two members, one empty); (B) only an understanding; (C) only a question with a blank answer — plus a fourth theme with nothing. After the call: A's note equals the expected full string, B's is the understanding, C's is `"# …\n"`, the fourth is `""`; `themeQuestions.isEmpty`; every `understanding == ""`; result is `(themes: 3, questions: 3)`. Reopen the store from disk and check the same.
  - `aSecondCallDoesNothing`: same state, result `(0, 0)`, no `updatedAt` change, hook not called.
  - `existingNoteTextIsKeptAndLegacyTextFollows`.
  - `evidenceForAnArticleThatLeftTheThemeIsNotListed` (the evidence list for a removed member is already stripped by `removeArticle`; also build the case where the link row is gone but the article exists: list by the article's title as a fallback only if it is still a member; otherwise skip).
  - `theHookRunsOnceAfterAMigrationThatRemovedQuestionsAndNotWhenNothingChanged`.
  - `aReviewBuiltFromOldQuestionsBecomesInvalidAfterMigration`: use the existing `AIPackageReview` test helpers (see `AIPackageTests`); a review generated with questions included must report changed after the migration.
  - `aFailedSaveChangesNothingAndARetrySucceeds` (with `gatedStore` / `SaveGate`): `gate.failNext = true`; the call throws; notes are still empty, questions and understandings are all still there; the next call succeeds.
  - `aVerificationFailureDeletesNothing`: inject a composer that drops text (a test-only closure parameter `compose:` with a default of `LegacyNoteText.compose`) and check `verificationFailed`, no save, nothing removed.
  - Add the migration to both failure-injection lists in `ThemeTests` (first call after a failed recovery also works, `induceFailedRecovery()`).
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.** `reloadIfNeeded()` first. Build the list of themes that have a non-blank understanding or any question. If none, return `(0, 0)` without a save. For each, compose with `existingNote: theme.note`; check `containsEverything`; throw `verificationFailed` before changing anything if one fails (compose all first, then apply). Apply: set `note`, clear `understanding`, delete the theme's questions, set `updatedAt`. One `save()`; on failure `save()` already rolls back. After success `try reload()` and `defer { onContentPolicyChanged?() }` when questions were deleted (same pattern as `deleteQuestion`).
- [ ] **Step 4: Run again.** Expected: all pass, including the two failure-injection lists.
- [ ] **Step 5: Check an older store.** Write a store with the current `main` code (a throwaway test or script outside the repository tree, in a detached worktree of `main`; themes with questions, answers, evidence), then open it with this branch, run the migration, and compare with the expected text. Record the result and the commits in the verification file (Task 6).
- [ ] **Step 6: Commit** (`feat: move understanding, questions and answers into the note in one save (N2)`).

### Task 4: The note face in the workspace state

**Files:**
- Modify: `Sources/ReaderCore/ReaderWorkspaceState.swift`
- Test: `Tests/ReaderCoreTests/ReaderWorkspaceTests.swift`

**Interfaces:**
- Produces: `ThemeFace { case articles, note }` (replaces `.questions`); `ThemeQuestionSelection` and the per-theme question selection are removed. Face restore per theme, `isReading`, and `switchFace` keep their behavior.

- [ ] **Step 1: Update the tests first** (rename `.questions` to `.note`, delete the question-selection tests, keep: leaving the articles face saves the reader; leaving the note face never overwrites it; the face is remembered per theme; `isReading` is false for the note face). Run: compile errors.
- [ ] **Step 2: Implement.** Run the workspace tests. Expected: pass.
- [ ] **Step 3: Commit** (`refactor: the second face of a theme is the note (N2)`).

### Task 5: The note face, the launch migration, and removing the question screens

**Files:**
- Modify: `Sources/RSSReader/ThemeViews.swift`, `Sources/RSSReader/ReaderView.swift`, `Sources/RSSReader/RSSReaderApp.swift`, `Sources/RSSReader/AIReviewView.swift`
- Create: `Sources/RSSReader/NoteEditor.swift`
- Delete: `Sources/RSSReader/QuestionEditor.swift`, `Sources/RSSReader/LensChoiceView.swift`; in `ThemeViews.swift` delete `ThemeQuestionsPane` and `UnderstandingEditor`
- Test: `Tests/ReaderUITests/ThemeReaderTests.swift`

**Interfaces:**
- Consumes: `saveNote`, `ThemeFace.note`, `migrateLegacyThemeContent`.
- Produces: `NoteEditor(store:themeID:)` (a `TextEditor` bound to `theme.note`, label 「ノート」, a save error shown in an alert and never dropped; the editor is rebuilt per theme with `.id(themeID)`).

- [ ] **Step 1: Update the UI tests first.** `ThemeFacePicker` shows 「記事」 and 「ノート」. Rewrite the `ThemeReaderTests` cases that used questions: the note face shows the note text of the selected theme; typing saves; a save error is reported; switching faces restores per theme; the migration alert text for success and failure (a pure function from the result to the message, tested without a window). Run: failures.
- [ ] **Step 2: Implement.**
  - `ThemeFacePicker`: `Text("記事").tag(.articles)`, `Text("ノート").tag(.note)`.
  - Middle column on the note face: `NoteEditor` under the face switch and the goal strip (replaces `ThemeQuestionsPane`). Right column on the note face: the existing `detail` (the selected article) or, by decision 5's fallback, the hint. `shortcutsEnabled` stays false on the note face (already tied to `isReading`).
  - `AIReviewView`: remove the two question toggles and their text; show 「テーマのノートはまだ Claude へ渡せません。」 for a theme review. The package still carries the theme's articles.
  - `RSSReaderApp`: after the store, `onContentPolicyChanged` and `handoff` exist, call `store.migrateLegacyThemeContent(at: .now)` inside its own `do` (not the startup `do`). On failure set `migrationError`; on success with `themes > 0` set `migrationNotice`. Then `handoff.reconcile(...)`. Two alerts: failure (「ノートへ移せませんでした」, body says the old content was not touched, buttons 「再試行」 and 「閉じる」) and the one-time success notice.
- [ ] **Step 3: Run the tests** (`swift test --scratch-path /private/tmp/feeeder-dogfooding-build`; whole suite). Expected: pass. Then `bash scripts/build-app.sh release`.
- [ ] **Step 4: Exercise a synthetic instance** with its own data directory (`open -n … --args --data-directory /private/tmp/feeeder-n2 --seed-demo`): a library written by `main` with questions is opened by the new build; the success notice shows; the note face shows the migrated text; typing and a face switch keep the text; the article stays visible on the right. Confirm the instance is the synthetic one first (AGENTS.md, Commands). Say which behaviors stay unverified on macOS (below).
- [ ] **Step 5: Commit** (`feat: the note face replaces the questions face, and the library migrates at launch (N2)`).

### Task 6: Documents, decision record, verification, review

**Files:**
- Modify: `docs/specification.md` (§3.2 theme definition and delete behavior, §3.3 rewritten around the note, the screen table, the AI paragraph, PRD-04, PRD-06, PRD-13), `docs/architecture.md` (model list, `Theme.note`, the migration, the face), `docs/user-guide.md` and `docs/user-guide.ja.md` (the screens, the note, the migration and the backup advice, the hand-off pause), the decision 0013 line "Impact" if its wording no longer matches
- Create: `docs/decisions/0014-note-migration-format.md` (decisions 1–3 above, with the date and "decider: the owner by merging the plan"), `docs/verification/2026-10-10-theme-note.md` (the result in its first three lines, then a table: migration tests, older-store check with commits, synthetic instance, timing of the 100,000-character save; what stays unverified)

- [ ] **Step 1:** Update the documents. The specification describes what is built: questions, lenses and answers disappear from it; the hand-off section says the theme context is paused until N6; the AI section keeps nearby themes, groups, and names (question proposals are gone from the UI).
- [ ] **Step 2:** `git diff --check`, check links.
- [ ] **Step 3: Independent review** of a fixed commit with `docs/review-checklist.md` (store, model, deletion): one pass, the reviewer lists what it checked and did not. Fix Critical and Important findings test-first, in one pass; list Minor ones in the PR.
- [ ] **Step 4:** Push the branch and open the PR (English). The PR text states: what it does not include (the deletion of unreachable question code, the hand-off with the note, two panes and the folding sidebar, the note editor scale, the AI features), the environment of each result, and the unverified list below.

## Unverified after this PR (stated in the PR)

- The migration on your real library (only synthetic stores and one older-store copy are tested). Back the data folder up first.
- Real Japanese IME in the note editor: composition, candidates, long text. The editor is SwiftUI `TextEditor`; if it cannot handle marked text correctly, a native input bridge follows (PR 10 says so too).
- VoiceOver on the note face and Reduce Motion. macOS 27.0 support floor (the local toolchain is macOS 27, CI is 26.6).
- Typing speed in a very long note (the 100,000-character save time is recorded, not judged).
- The temporary right column (decision 5) on a real window.

## Not in this PR

Two panes with the folding sidebar (N3). The AI summary and note actions (N4, N5). The hand-off with the goal and the note (N6). The note editor scale (PR 10). Removal of the unreachable question store code and its tests (N2b). Removal of `ThemeQuestion` and `Theme.understanding` from the schema (before 1.0).
