# N6: Claude hand-off with the goal and the note — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This project keeps one supervised implementer ([decision 0002](../../decisions/0002-single-supervised-writer.md)).

**Goal:** The person can hand a theme's learning goal and note to Claude (the Cowork route that already exists) and ask for a review of the note against the goal, with the theme's articles as optional sources. They see exactly what leaves the Mac, and nothing leaves by accident.

**Architecture:** The theme part of the package changes from "questions, answers and evidence" to "the goal and the note". `AIThemeRequest` says which of the two are included; `AIThemeContext` carries their text; the package text gets a review request and a `BEGIN_THEME` section with the goal and the note as the person's own words. The review screen gets two switches. A package may have no article sources when it carries the goal or the note. Managed copies follow the theme (not the questions). A button in the note panel opens the review screen with the goal and the note switched on. Nothing about launching Claude changes.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, CryptoKit (existing). No new dependency, no new launch path.

**Spec:** [decision 0013](../../decisions/0013-goal-and-note-for-themes.md) (point 7), [decision 0012](../../decisions/0012-claude-handoff-from-themes.md) (which this refines), [decision 0009](../../decisions/0009-on-device-ai-principles.md), [the goal review experiment](../../verification/2026-10-11-goal-review-experiment.md) (the reason a review is asked of Claude and not of the on-device model), PRD §5.2. Merging this plan approves it. Plan approval is not product acceptance.

**Language:** New project text is in English (AGENTS.md, "Language"). App labels stay Japanese; they are quoted as they appear, with a short English gloss.

## Decisions for you (merging approves them)

1. **Two switches on the review screen.** 「ゴールを含める」 (Include my goal): on by default when the theme has a goal, disabled with 「ゴールがありません」 when it has none. 「ノートを含める」 (Include my note): **off by default**, disabled with 「ノートが空です」 when the note is empty. A line says: 「ノートは自分で書いた文章です。含めると、確認した内容のとおり、この Mac の外（Claude）へ渡ります。」 The switches replace the question and answer switches of decision 0012.
2. **A button in the note panel starts the review.** 「Claudeでレビューを頼む」 (Ask Claude to review) in the note panel header opens the same review screen with **the goal and the note both on**, because asking for a review is the explicit intent. The toolbar button 「Claudeで開く…」 keeps the default of decision 0013 (note off). In both cases the person sees the full text and must press 「Claudeで開く」 themselves.
3. **What Claude is asked.** When the note is included, the package says: review the person's note against the person's goal; name what the note already achieves, quoting the note; name what is still missing for the goal, only on the basis of what the note does **not** say, and never say that something is missing when the note says it (the on-device experiment's main failure); name weak support or opposing views from the sources if sources are included; suggest what to read or write next; do not rewrite the note and do not write into the app. When only the goal is included, or neither, the existing request for the sources (main points, common points, differences, questions) stays. The reply is read and used by the person; nothing is written back.
4. **Sources become optional when the goal or the note is included.** Today at least one article source is required. A review of a note alone is the main use, so a package with the goal and/or the note and **no** article is allowed. Such a package lives 24 hours (no article to expire earlier). With neither the goal nor the note, at least one source is still required, as in decision 0012.
5. **Review invalidation.** If the goal or the note changes after the person reviewed the package, or the theme is renamed, the review becomes invalid and must be made again (the same rule as for answers). A managed copy is **not** deleted when the note is edited (it is a labelled snapshot that Claude may be reading), is deleted when the theme is deleted or a source article leaves the theme, and expires after 24 hours; this is decision 0012's rule with the questions removed.
6. **Marker-like text stays data.** The goal and the note are put in the package verbatim between `BEGIN_THEME` and `END_THEME`; lines in them that look like package markers are not interpreted (the existing rule for the person's words), and the split into 1 MiB parts stays lossless.
7. **Not in this PR.** Any change to how Claude Desktop is launched, an automatic reply, writing Claude's reply into the note, the on-device review panel (L4, narrowed by the experiment), the styled editor (L2), and the removal of the unreachable question code (N2b), except what this PR makes unused in the package code, which it deletes.

## Global Constraints

- Decision 0009: the only route that sends content off the Mac is this reviewed hand-off; the person always sees exactly what leaves; nothing is sent automatically; the note is the person's own writing, so it is off by default in the toolbar entry. Support floor macOS 27.0; build floor and CI stay macOS 26.6 / Swift 6.3.3.
- No new launch path and no new claim about Claude Desktop (the only checked route is 2.19675.0 / Pro / Cowork). Do not press the real launch button in verification; use the fake launcher.
- Managed copies and the review are reconciled through `onContentPolicyChanged` as now. A deletion or an invalidation never needs a successful reload to happen.
- Tests use synthetic data and a fake launcher only. One theme per PR. Failing tests first. Commit and PR text in English. Add the attribution line the session gives. Do not push to `main`, sign, or release. After implementation and one independent review of a fixed commit, push the branch and open the PR without asking.
- UI tests: wait by pumping the run loop (no `Task.sleep` after creating windows, see the N4 record); a suite of its own; run each alone; private settings stores.

## Review Focus

1. A note or goal containing lines that look like package markers (`END_THEME`, `BEGIN_SOURCE …`), CRLF, emoji, a very long note (over 1 MiB) → the package text is verbatim and the split is lossless (Task 1).
2. Editing the note, the goal or the theme name after the review makes the review invalid; editing does not delete a managed copy; deleting the theme does (Task 1, Task 2).
3. A package with no sources: its expiry, its managed copy, its reconcile, and the rule that with neither goal nor note the old "at least one source" rule holds (Task 1, Task 2).
4. The defaults: the toolbar entry has the note off, the note panel entry has goal and note on, an empty goal or note disables its switch, and what is shown on screen equals what is exported, copied, and launched (Task 3).
5. Copies written before this change (with `questionIDs` in their metadata) still decode and are cleaned up (Task 2).

---

### Task 1: The package carries the goal and the note

**Files:**
- Modify: `Sources/ReaderCore/AIPackage.swift`
- Test: `Tests/ReaderCoreTests/AIPackageTests.swift`

**Interfaces:**
- Produces: `AIThemeRequest(themeID:includeGoal:includeNote:)`; `AIThemeContext(themeID:themeName:goal:note:)` with `goal` and `note` as `String?` (nil when not included); `ReaderStore.aiThemeContext(_:)` returns the context for a request (nil when neither is included or the theme is gone); `AIPackageBuilder.build` accepts no sources when a context with a goal or a note is given; `AIPackageReview.build(selections:theme:language:at:)` and `reconcile` follow. `AIPackageError.noQuestions` is removed; `AIThemeContext.Question`, `.Evidence`, `lens`, `includesAnswers` are removed.

- [ ] **Step 1: Write the failing tests** (replace the question tests of `AIPackageTests` by these; keep the tests that are not about questions): the theme section contains the goal and the note under labels that say they were written by the user; with the note off the text does not contain it; with the goal off it does not contain the goal; the review request text is present when the note is included and the old source request when it is not (compare against literals so a change is deliberate); a note with `END_THEME`, `BEGIN_SOURCE x` lines, CRLF, and emoji is in the text byte for byte; a 1.5 MiB note splits losslessly (concatenated payloads equal the text); a package with the goal only and no sources builds, expires after 24 hours, and has the right hash; with neither goal nor note and no sources it throws `.empty`; editing the note, the goal or the theme name after `build` makes `validated` throw (one test per edit); deleting the theme invalidates; a note edit when the note is not included does not invalidate; the package's theme link (`themeID`) is kept for packages made from a theme.
- [ ] **Step 2: Run** `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter AIPackageTests`. Expected: compile errors.
- [ ] **Step 3: Implement.** The theme section: `BEGIN_THEME <id>`, `Theme: <one-line name>`, `Goal (written by the user):`, the goal, `Note (written by the user):`, the note, `END_THEME <id>`. The review request is added to the package header only when the note is included.
- [ ] **Step 4: Run again. Step 5: Commit** (`feat: the Claude package carries the goal and the note (N6)`).

### Task 2: Managed copies follow the theme, and a package may have no sources

**Files:**
- Modify: `Sources/ReaderCore/HandoffFiles.swift`, `Sources/ReaderCore/ClaudeHandoffController.swift`
- Test: `Tests/ReaderCoreTests/ClaudeHandoffTests.swift`

- [ ] **Step 1: Write the failing tests** (replace the question tests): a package without sources is written, split-written, read back, and cleaned up after 24 hours; its metadata has the theme ID and no question IDs; a copy written by the old code (metadata JSON with `questionIDs` and a theme ID) still decodes and is deleted at the next reconcile when the theme or a source is gone (and kept when they exist); deleting the theme deletes its copy at once (through `onContentPolicyChanged`); removing a source article from the theme deletes the copy; editing the note or the goal and renaming the theme do not delete a copy; the controller reconcile with no sources does not fail (no `min()` of an empty list).
- [ ] **Step 2: Run, see them fail. Step 3: Implement** (`Metadata.questionIDs` stays optional and unused; `themeContextIsValid` checks the theme and the source articles only; the review's expiry is 24 hours when there are no article expiries). **Step 4: Run again.**
- [ ] **Step 5: Commit** (`feat: managed copies follow the theme only, and a package may have no sources (N6)`).

### Task 3: The review screen and the entry in the note panel

**Files:**
- Modify: `Sources/RSSReader/AIReviewView.swift`, `Sources/RSSReader/NotePanel.swift`, `Sources/RSSReader/ReaderView.swift`
- Test: `Tests/ReaderUITests/ThemeReaderTests.swift` (a new suite `HandoffEntryTests`), a pure test for the default rule

**Interfaces:**
- Produces: `AIReviewView(..., themeID:, includeNoteByDefault:)`; a pure `HandoffDefaults.switches(goal:note:fromNotePanel:) -> (goalOn, noteOn, goalEnabled, noteEnabled)` in ReaderCore (tested).

- [ ] **Step 1: Write the failing tests.** Pure: the default rule from decision 1 and 2 (toolbar: goal on if present, note off; note panel: both on if present; empty goal or note: off and disabled). UI (borderless buttons, a fake launcher): the note panel shows 「Claudeでレビューを頼む」 only inside a theme and disabled while the theme has neither a goal nor a note and no sources; pressing it opens the sheet with the goal and note switches on; the toolbar entry opens it with the note off; the package text shown on screen contains the note only while the switch is on and changes at once when it is switched; with the switch on and the note edited afterwards the sheet's package is invalid (the existing reconcile).
- [ ] **Step 2: Run, see them fail. Step 3: Implement.** Replace the two question toggles and their texts with the two switches and the line about the person's own writing; remove the paused-note line added by N2.
- [ ] **Step 4: Run each UI test alone and the whole suite. Step 5: Commit** (`feat: ask Claude to review the note against the goal (N6)`).

### Task 4: Documents, verification, review

**Files:**
- Modify: `docs/specification.md` (§5.2, PRD-05), `docs/architecture.md` (the theme content part), both user guides (the hand-off part: remove "paused" wording), `README.md`; create `docs/decisions/0018-handoff-goal-and-note.md` (decisions 1 to 6) and `docs/verification/2026-10-11-handoff-goal-note.md`.

- [ ] **Step 1:** Update the documents; `git diff --check`; whole suite; release build.
- [ ] **Step 2: One independent review** of a fixed commit with `docs/review-checklist.md` (external write: what leaves the Mac) and the Review Focus above. Fix Critical and Important findings test-first in one pass.
- [ ] **Step 3:** Push the branch and open the PR (English), with what it does not include and the unverified list. The PR says plainly that the PdM's real launch of Claude Desktop with a note (PRD-05 acceptance) is still to be done by the PdM, and that the real usefulness of the review is not judged.

## Unverified after this PR (stated in the PR)

- A real launch into Claude Desktop with the goal and the note, and what Claude's review is like. Claude Desktop versions, plans, and routes other than the one that was checked. A very large note through the Cowork route. IME and VoiceOver on the review screen; macOS 26 CI.

## Not in this PR

A change to the launch path, an automatic or written-back reply, the on-device review panel (L4), the styled editor (L2), and the removal of the unreachable question code (N2b) beyond what the package code no longer uses.
