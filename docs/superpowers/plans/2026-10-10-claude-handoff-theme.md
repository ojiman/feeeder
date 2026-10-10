# Claude hand-off from a theme (PR 8) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This project keeps one supervised implementer ([decision 0002](../../decisions/0002-single-supervised-writer.md)).

**Goal:** Bring back "Open in Claude" (「Claudeで開く」), now from a theme. The review screen lets the person choose the output language, which sources to include, whether to include the theme's questions, and whether to include their own answers. Everything that will be sent is shown on the screen first. When something the package or a managed copy contains is deleted, the copy is removed.

**Architecture:** The hand-off machinery already exists (package builder with SHA-256, review object, managed copies, launch link, review screen). PR 8 adds a *theme context* to the package (the theme's questions, optionally the person's answers and chosen evidence), checks it again on every reconcile, records it in the managed copy's metadata, deletes the copy when the theme, an included question, or an included source is deleted, and puts an entry point in the theme view. No new launch path: only the Cowork route that was already checked is used.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SwiftData, CryptoKit, Swift Testing. No new dependency.

**Spec:** [PRD](../../specification.md) §3.3, §5.2, PRD-05; [Architecture](../../architecture.md) §3.2; [decision 0005](../../decisions/0005-v1-product-decisions-2026-10-04.md) (Claude hand-off), [0009](../../decisions/0009-on-device-ai-principles.md) (the only route that sends content off the Mac is the existing, reviewed Claude hand-off). Earlier PRs of the roadmap: #23, #25, #27, #30, #32 (main `1877c3f`). Merging this plan approves it. Plan approval is not product acceptance.

**Language:** New project text is in English (AGENTS.md, "Language"). App labels stay Japanese; they are quoted as they appear, with a short English gloss.

## Decisions for you (merging approves them)

I chose these. The rule I used: the person always sees exactly what leaves the Mac, and nothing leaves by accident. Tell me before merging if you want a different choice.

1. **Where the entry is.** A toolbar button 「Claudeで開く…」 (Open in Claude) that appears whenever a theme is selected (both the Articles face and the Questions face). It opens the existing review screen as a sheet. It is disabled when the theme has no article that can be a source.
2. **Defaults.** Questions are included, **answers are not**. The person turns answers on by choice. The answers switch is off and disabled while questions are off. A short note says that answers are the person's own writing and will leave the Mac.
3. **What can be chosen.** Output language; each source separately (the saved RSS summary, or the retained article text, never both for one article); questions on/off; answers on/off (when on, the evidence articles the person chose for each question are listed too). The theme's "current understanding" (「いまの理解」) is **not** included. This follows the spec (§5.2 lists questions, answers, sources).
4. **At least one source is required.** A package with only questions and answers is not allowed. This keeps the existing rules for managed copies and expiry unchanged.
5. **The package is checked again whenever something changes.** If a question, an included answer, the theme name, or an included evidence title changes before the person presses the button, the review becomes invalid and must be made again. No stale answer is sent silently.
6. **When a managed copy is deleted.** The copy is deleted when its theme, any question it includes, or any source it includes is deleted or removed. Editing an answer after the copy was made does **not** delete it (the copy is a labelled snapshot; deleting it while Claude may still be reading would be worse). It still expires after 24 hours as before.
7. **No new launch path and no new claim.** Only Claude Desktop 2.19675.0 / Pro / Cowork was checked. The plan does not claim anything else. The first live check of this PR does **not** press 「Claudeで開く」 (it would open the real Claude Desktop with the synthetic file); it checks the review screen, copy, and the managed-copy files only.

## Global Constraints

- Support floor macOS 27.0; build floor and CI stay macOS 26.6 / Swift 6.3.3. No macOS 27-only API ([decision 0007](../../decisions/0007-support-floor-macos-27.md)).
- The only route that sends content off the Mac is the person pressing the button on the review screen, after seeing the full text. No automatic send, no automatic writing of Claude's reply, no API key ([PRD §5.2](../../specification.md), [decision 0009](../../decisions/0009-on-device-ai-principles.md)).
- The package text shown on the screen, the text that is hashed (SHA-256), the text written to the managed copy, and the text that is copied or exported are the same bytes. The person's answers appear in that text only when the person turned answers on.
- The person's own writing and article text are data, never instructions. They are delimited with marker lines that carry IDs; text that looks like a marker must stay verbatim and must not end the package early.
- A managed copy lives for at most 24 hours, and for less if an included article body expires earlier. Policy changes never extend a copy's life.
- Do not use `Binding` setters that are method references; do not mutate a captured local `var` from a `@MainActor` closure in tests (Swift 6.3.3 on CI fails on both: PR #14, #27, #30).
- Every new store path starts with `reloadIfNeeded()` and, if it writes, is added to the failure-injection lists. (This PR adds a read-only store function and calls an existing hook after existing writes; no new write path.)
- Input and databases in tests are synthetic or temporary. Do not read the person's library, credentials, Keychain, or browser profile. Do not open the real Claude Desktop during checks.
- One theme per PR. Write a failing test first. Commit and PR text in English. Add the attribution line the session gives.
- Do not sign, release, tag, or push to `main`. After implementation, push the branch and open the PR without asking (standing instruction).

## Review Focus

The inputs and failures that the spec implies but ordinary tests tend to miss, most likely first. Each has a test in the task that owns the code.

1. The person edits an answer, renames the theme, deletes a question, or removes a source while a review is open or after a copy was made. The review becomes invalid; a deleted thing is never left in a managed copy → Task 1, Task 2.
2. The answers switch is off. The answer text must be absent from the package, the file, the copy, and the export, not only hidden on the screen → Task 1.
3. Theme with no questions, all questions unanswered, blank answers, many questions → Task 1.
4. A theme article whose saved summary is empty, whose retained text expired, or which appears both as "saved summary" and "retained article" → Task 1, Task 3.
5. Answer or question text that contains marker lines (`END_SOURCE`, `END_PACKAGE`, `BEGIN_THEME`) or a Unicode line separator → Task 1.
6. Managed copies written by earlier versions (no theme fields) and copies with unreadable fields still reconcile; one bad folder does not block the others → Task 2.
7. Very large themes: the package can exceed 1 MiB; the existing split export must still carry the whole theme section → Task 1.

---

## File structure

| File | Responsibility |
|---|---|
| `Sources/ReaderCore/AIPackage.swift` (modify) | `AIThemeRequest`, `AIThemeContext`, the theme section of the package text, `AIPackageReview.build(…theme:)` and the re-check in `reconcile` |
| `Sources/ReaderCore/HandoffFiles.swift` (modify) | `themeID` and `questionIDs` in the managed copy's metadata, and removal of a copy whose theme or question is gone |
| `Sources/ReaderCore/ClaudeHandoffController.swift` (modify) | pass the theme check to `reconcile` |
| `Sources/ReaderCore/Themes.swift` (modify) | call the existing `onContentPolicyChanged` after `deleteTheme`, `removeArticle`, `deleteQuestion` |
| `Sources/RSSReader/AIReviewView.swift` (modify) | the two switches, the note, the theme request |
| `Sources/RSSReader/ReaderView.swift` (modify) | the toolbar button and the sheet |
| `Tests/ReaderCoreTests/AIPackageTests.swift`, `ClaudeHandoffTests.swift` (modify) | tests |
| `docs/user-guide.md`, `docs/user-guide.ja.md`, `README.md`, `docs/specification.md`, `docs/architecture.md`, `docs/decisions/0012-claude-handoff-from-themes.md`, `docs/verification/2026-10-10-claude-handoff-theme.md` | documents and records |

Test command: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter <name>`. CI uses `--scratch-path /private/tmp/feeeder-ci-build --force-resolved-versions --disable-keychain --disable-netrc`.

---

### Task 1: Theme context in the package

**Files:**
- Modify: `Sources/ReaderCore/AIPackage.swift`
- Test: `Tests/ReaderCoreTests/AIPackageTests.swift`

**Interfaces:**
- Consumes: `ReaderStore.theme(id:)`, `questions(themeID:)`, `themeArticles`, `ThemeQuestion` (`id`, `lens`, `text`, `answer`, `evidenceArticleIDs`), `QuestionLens.title`
- Produces:
  - `public struct AIThemeRequest: Sendable, Equatable, Hashable { themeID: UUID; includeQuestions: Bool; includeAnswers: Bool }`
  - `public struct AIThemeContext: Sendable, Equatable { themeID; themeName; questions: [Question]; includesAnswers: Bool }` with `Question { id, lens, text, answer: String?, evidence: [Evidence] }` and `Evidence { title, url: String? }`
  - `ReaderStore.aiThemeContext(_ request: AIThemeRequest) -> AIThemeContext?`
  - `AIPackage.theme: AIThemeContext?`; `AIPackageBuilder.build(sources:theme:language:createdAt:expiresAt:)` (`theme` defaults to nil)
  - `AIPackageReview.build(selections:theme:language:at:)` (`theme: AIThemeRequest?` defaults to nil); a new `AIPackageError.noQuestions`

- [ ] **Step 1: Write the failing tests**

Add to `AIPackageTests` (these use the existing `TestLibrary`):

```swift
    // MARK: Theme context

    /// A theme with one saved-summary source and two questions; the first is answered and has evidence.
    private func themeFixture(_ at: Date) throws -> (library: TestLibrary, store: ReaderStore, theme: Theme, link: ThemeArticle, answered: ThemeQuestion, blank: ThemeQuestion) {
        let library = try TestLibrary()
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "Recorded synthetic summary"
        let theme = try store.createTheme(name: "Rates and households", at: at)
        let link = try store.addArticle(article.id, toTheme: theme.id, at: at)
        let answered = try store.addQuestion(themeID: theme.id, lens: .assumption, text: "What does this assume about wages?", at: at)
        try store.saveAnswer(questionID: answered.id, answer: "It assumes wages rise as fast as rates.\nI am not sure that holds.", at: at)
        try store.setEvidence(questionID: answered.id, articleIDs: [article.id], at: at)
        let blank = try store.addQuestion(themeID: theme.id, lens: .tradeoff, text: "What is given up?", at: at.addingTimeInterval(1))
        return (library, store, theme, link, answered, blank)
    }

    @Test func questionsAndAnswersAreIncludedOnlyWhenAsked() throws {
        let at = Date.now
        let (library, store, theme, link, answered, blank) = try themeFixture(at); defer { library.cleanup() }
        let review = AIPackageReview(store: store, now: { at })

        try review.build(selections: [.themeArticle(link.key)], theme: AIThemeRequest(themeID: theme.id, includeQuestions: true, includeAnswers: true), language: "English", at: at)
        let full = try #require(review.package)
        #expect(full.text.contains("BEGIN_THEME \(theme.id.uuidString)") && full.text.contains("Theme: Rates and households"))
        #expect(full.text.contains("BEGIN_QUESTION \(answered.id.uuidString)") && full.text.contains("What does this assume about wages?"))
        #expect(full.text.contains("It assumes wages rise as fast as rates.\nI am not sure that holds."))
        #expect(full.text.contains("(not written yet)") && full.text.contains("BEGIN_QUESTION \(blank.id.uuidString)"))
        #expect(full.text.contains("- \(store.articles[0].title)"))                                   // the chosen evidence
        #expect(full.theme?.includesAnswers == true && full.sha256 == AIPackageBuilder.hash(Data(full.text.utf8)))

        try review.build(selections: [.themeArticle(link.key)], theme: AIThemeRequest(themeID: theme.id, includeQuestions: true, includeAnswers: false), language: "English", at: at)
        let questionsOnly = try #require(review.package)
        #expect(questionsOnly.text.contains("What does this assume about wages?"))
        #expect(!questionsOnly.text.contains("It assumes wages rise") && !questionsOnly.text.contains("My answer") && !questionsOnly.text.contains("(not written yet)"))
        #expect(!questionsOnly.text.contains("Evidence chosen") && questionsOnly.theme?.includesAnswers == false)

        try review.build(selections: [.themeArticle(link.key)], theme: AIThemeRequest(themeID: theme.id, includeQuestions: false, includeAnswers: true), language: "English", at: at)
        let none = try #require(review.package)
        #expect(!none.text.contains("BEGIN_THEME") && !none.text.contains("What does this assume") && none.theme == nil)
        try review.build(selections: [.themeArticle(link.key)], language: "English", at: at)
        #expect(review.package?.theme == nil && review.package?.text.contains("BEGIN_THEME") == false)
    }

    @Test func aThemeWithoutQuestionsCannotBeSentAsQuestions() throws {
        let at = Date.now
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "Empty", at: at)
        let link = try store.addArticle(store.articles[0].id, toTheme: theme.id, at: at)
        let review = AIPackageReview(store: store, now: { at })
        #expect(throws: AIPackageError.self) {
            try review.build(selections: [.themeArticle(link.key)], theme: AIThemeRequest(themeID: theme.id, includeQuestions: true, includeAnswers: false), language: "English", at: at)
        }
        #expect(review.package == nil && review.reason != nil)
    }

    @Test func aReviewBecomesInvalidWhenWhatItContainsChanges() throws {
        let at = Date.now
        let (library, store, theme, link, answered, blank) = try themeFixture(at); defer { library.cleanup() }
        let review = AIPackageReview(store: store, now: { at })
        let request = AIThemeRequest(themeID: theme.id, includeQuestions: true, includeAnswers: true)
        func rebuild() throws { try review.build(selections: [.themeArticle(link.key)], theme: request, language: "English", at: at) }

        try rebuild()
        _ = try review.validated(at: at)                                                  // unchanged stays valid
        _ = try review.validated(at: at)
        try store.saveAnswer(questionID: answered.id, answer: "Changed my mind.", at: at)
        #expect(throws: (any Error).self) { try review.validated(at: at) }
        #expect(review.package == nil)

        try rebuild(); try store.renameTheme(id: theme.id, to: "Renamed", at: at)
        #expect(throws: (any Error).self) { try review.validated(at: at) }
        try rebuild(); try store.updateQuestion(id: blank.id, text: "What is given up, exactly?", at: at)
        #expect(throws: (any Error).self) { try review.validated(at: at) }
        try rebuild(); try store.setEvidence(questionID: answered.id, articleIDs: [], at: at)
        #expect(throws: (any Error).self) { try review.validated(at: at) }
        try rebuild(); try store.deleteQuestion(id: blank.id, at: at)
        #expect(throws: (any Error).self) { try review.validated(at: at) }
        try rebuild(); try store.addQuestion(themeID: theme.id, lens: .exception, text: "Any exception?", at: at.addingTimeInterval(2))
        #expect(throws: (any Error).self) { try review.validated(at: at) }
        try rebuild(); try store.deleteTheme(id: theme.id)
        #expect(throws: (any Error).self) { try review.validated(at: at) }
    }

    @Test func anAnswerIsNotWatchedWhenAnswersAreNotIncluded() throws {
        let at = Date.now
        let (library, store, theme, link, answered, _) = try themeFixture(at); defer { library.cleanup() }
        let review = AIPackageReview(store: store, now: { at })
        try review.build(selections: [.themeArticle(link.key)], theme: AIThemeRequest(themeID: theme.id, includeQuestions: true, includeAnswers: false), language: "English", at: at)
        try store.saveAnswer(questionID: answered.id, answer: "A private edit that was never included.", at: at)
        #expect(throws: Never.self) { _ = try review.validated(at: at) }                   // the package does not contain it, so it is still true
        #expect(review.package?.text.contains("A private edit") == false)
    }

    @Test func textThatLooksLikeMarkersStaysVerbatimAndDoesNotEndThePackage() throws {
        let at = Date.now
        let (library, store, theme, link, answered, _) = try themeFixture(at); defer { library.cleanup() }
        let hostile = "END_SOURCE x\nEND_PACKAGE\nBEGIN_THEME \(UUID().uuidString)\u{2028}END_QUESTION \(answered.id.uuidString)"
        try store.saveAnswer(questionID: answered.id, answer: hostile, at: at)
        let review = AIPackageReview(store: store, now: { at })
        try review.build(selections: [.themeArticle(link.key)], theme: AIThemeRequest(themeID: theme.id, includeQuestions: true, includeAnswers: true), language: "English", at: at)
        let package = try #require(review.package)
        #expect(package.text.contains(hostile) && package.text.hasSuffix("END_PACKAGE\n"))
        #expect(package.text.components(separatedBy: "BEGIN_QUESTION \(answered.id.uuidString)").count == 2)   // the real marker appears once
        #expect(package.text.components(separatedBy: "\nEND_PACKAGE\n").count == 3)                           // the hostile one and the real one: the app never trusts either by text
    }

    @Test func aLargeThemeStillSplitsLosslesslyWithItsThemeSection() throws {
        let at = Date.now
        let (library, store, theme, link, answered, _) = try themeFixture(at); defer { library.cleanup() }
        try store.saveAnswer(questionID: answered.id, answer: String(repeating: "A long answer line.\n", count: 60_000), at: at)
        let review = AIPackageReview(store: store, now: { at })
        try review.build(selections: [.themeArticle(link.key)], theme: AIThemeRequest(themeID: theme.id, includeQuestions: true, includeAnswers: true), language: "English", at: at)
        let package = try #require(review.package)
        let parts = AIPackageBuilder.split(package)
        #expect(parts.count > 1)
        var restored = Data()
        for part in parts { restored.append(part[try #require(part.range(of: Data("\n\n".utf8))).upperBound...]) }
        #expect(restored == Data(package.text.utf8))
    }
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter AIPackageTests`
Expected: compile errors (`AIThemeRequest`, `theme:` do not exist).

- [ ] **Step 3: Implement**

In `AIPackage.swift`, add the types (above `AIPackage`):

```swift
/// What the person chose to include from a theme. Answers need questions.
public struct AIThemeRequest: Sendable, Equatable, Hashable {
    public let themeID: UUID
    public let includeQuestions: Bool
    public let includeAnswers: Bool
    public init(themeID: UUID, includeQuestions: Bool, includeAnswers: Bool) {
        self.themeID = themeID; self.includeQuestions = includeQuestions; self.includeAnswers = includeAnswers
    }
}

/// The theme's questions as they were when the package was made. Compared again on every reconcile, so any change
/// to what the package contains makes the review invalid.
public struct AIThemeContext: Sendable, Equatable {
    public struct Evidence: Sendable, Equatable {
        public let title: String
        public let url: String?
    }
    public struct Question: Sendable, Equatable {
        public let id: UUID
        public let lens: String
        public let text: String
        /// nil when answers are not included; "" when they are included but not written yet.
        public let answer: String?
        public let evidence: [Evidence]
    }
    public let themeID: UUID
    public let themeName: String
    public let questions: [Question]
    public let includesAnswers: Bool
}
```

`AIPackage` gets `public let theme: AIThemeContext?` and `shorteningExpiry` passes it. Add `case noQuestions` to `AIPackageError` with the message `"このテーマには問いがありません。問いを含めない設定にしてください。"` (Japanese: "This theme has no questions. Turn the questions off.").

`AIPackageBuilder.build` takes `theme: AIThemeContext? = nil` (after `sources`). After the existing fixed paragraph, when `theme != nil` add this paragraph, and after it the theme section, before the sources:

```swift
        if let theme {
            text += "このテーマについて本人が立てた問い（含まれている場合は本人の答えと根拠も）を、BEGIN_THEME から END_THEME の間に示します。本人の考えは本人のものとして尊重し、出典に基づいて、答えの抜け・反対の見方・根拠の弱い点を指摘してください。本人の答えを書き換えず、自動で書き込まないでください。\n\n"
            text += themeSection(theme)
        }
```

(Insert it before `for source in sources`; the existing `text` initialiser already ends with a blank line.) Add:

```swift
    static func themeSection(_ theme: AIThemeContext) -> String {
        var text = "BEGIN_THEME \(theme.themeID.uuidString)\nTheme: \(theme.themeName)\nQuestions: \(theme.questions.count)\nAnswers: \(theme.includesAnswers ? "included" : "not included")\n\n"
        for question in theme.questions {
            text += "BEGIN_QUESTION \(question.id.uuidString)\nLens: \(question.lens)\nQuestion:\n\(question.text)\n"
            if let answer = question.answer {
                let written = answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(not written yet)" : answer
                text += "My answer (written by the user):\n\(written)\n"
                if !question.evidence.isEmpty {
                    text += "Evidence chosen by the user:\n" + question.evidence.map { "- \($0.title)" + ($0.url.map { " <\($0)>" } ?? "") }.joined(separator: "\n") + "\n"
                }
            }
            text += "END_QUESTION \(question.id.uuidString)\n\n"
        }
        return text + "END_THEME \(theme.themeID.uuidString)\n\n"
    }
```

The returned `AIPackage` gets `theme: theme`.

Add the store function and the review changes:

```swift
extension ReaderStore {
    /// The theme's questions (and, when asked, the person's answers and chosen evidence) as they are right now.
    /// Nil when no questions are asked for, the theme is gone, or it has none.
    public func aiThemeContext(_ request: AIThemeRequest) -> AIThemeContext? {
        guard request.includeQuestions, let theme = theme(id: request.themeID) else { return nil }
        let questions = self.questions(themeID: request.themeID)
        guard !questions.isEmpty else { return nil }
        return AIThemeContext(themeID: theme.id, themeName: theme.name, includesAnswers: request.includeAnswers, questions: questions.map { question in
            AIThemeContext.Question(id: question.id, lens: question.lens.title, text: question.text,
                answer: request.includeAnswers ? question.answer : nil,
                evidence: request.includeAnswers ? question.evidenceArticleIDs.compactMap { id in
                    themeArticles.first { $0.themeID == theme.id && $0.articleID == id }.map { AIThemeContext.Evidence(title: $0.title, url: $0.url) }
                } : [])
        })
    }
}
```

(The memberwise initialisers of the nested structs are internal; the call is in the same module. Reorder the `AIThemeContext(...)` arguments to match the property order: `themeID, themeName, questions, includesAnswers`.)

In `AIPackageReview`: `build(selections:theme:language:at:)`:

```swift
    public func build(selections: [AIInputSelection], theme: AIThemeRequest? = nil, language: String, at: Date) throws {
        clear()
        do {
            guard !selections.isEmpty else { throw AIPackageError.empty }
            let sources = try store.aiSources(selections: selections, at: at)
            let expiries = try store.availableInputExpiries(selections: selections, at: at)
            guard sources.count == selections.count, let expiry = expiries.values.min() else { throw AIPackageError.unavailable }
            var context: AIThemeContext?
            if let theme, theme.includeQuestions {
                guard let current = store.aiThemeContext(theme) else { throw AIPackageError.noQuestions }
                context = current
            }
            package = try AIPackageBuilder.build(sources: sources, theme: context, language: language, createdAt: at, expiresAt: expiry)
        } catch { reason = error.localizedDescription; throw error }
    }
```

The existing `build(articleIDs:…)` keeps calling `build(selections:language:at:)` (the new parameter has a default). In `reconcile`, after the `zip(...)` equality guard add:

```swift
            if let context = prior.theme {
                let request = AIThemeRequest(themeID: context.themeID, includeQuestions: true, includeAnswers: context.includesAnswers)
                guard store.aiThemeContext(request) == context else { throw AIPackageError.changed }
            }
```

- [ ] **Step 4: Run the tests and check them with mutations**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter AIPackageTests` → all pass. Then commit and check by mutation, restoring each by a targeted replacement (never `git checkout` over uncommitted work): (a) in `aiThemeContext`, always pass `question.answer` (ignore `includeAnswers`) → `questionsAndAnswersAreIncludedOnlyWhenAsked` fails; (b) drop the `reconcile` re-check → `aReviewBecomesInvalidWhenWhatItContainsChanges` fails; (c) make `themeSection` skip `BEGIN_QUESTION` markers → the marker test fails.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReaderCore/AIPackage.swift Tests/ReaderCoreTests/AIPackageTests.swift
git commit -m "feat: add the theme's questions, answers, and evidence to the Claude package"
```

---

### Task 2: Managed copies follow the theme

**Files:**
- Modify: `Sources/ReaderCore/HandoffFiles.swift`, `Sources/ReaderCore/ClaudeHandoffController.swift`, `Sources/ReaderCore/Themes.swift`
- Test: `Tests/ReaderCoreTests/ClaudeHandoffTests.swift`

**Interfaces:**
- Consumes: Task 1 (`AIPackage.theme`)
- Produces: `HandoffFiles.reconcile(directory:validInputExpiries:themeContextIsValid:at:)` (the new parameter defaults to "always valid", so existing calls compile); `HandoffFiles.Metadata.themeID` / `questionIDs` (optional, so older copies still decode); `ClaudeHandoffController.reconcile(with:at:)` removes a copy whose theme or question is gone; `deleteTheme`, `removeArticle`, `deleteQuestion` call `onContentPolicyChanged`.

- [ ] **Step 1: Write the failing tests**

Add to `ClaudeHandoffTests` (it already has `ProbeLauncher` and a `fixture()` helper; these tests build their own store to stay independent):

```swift
    /// Store + theme with one question, a package that includes the theme's questions and answers, and a controller that is wired
    /// the way the app wires it (a store change calls the controller's reconcile).
    private func themeCopy(_ at: Date) throws -> (library: TestLibrary, store: ReaderStore, theme: Theme, link: ThemeArticle, question: ThemeQuestion, controller: ClaudeHandoffController, folder: URL, launcher: ProbeLauncher) {
        let library = try TestLibrary()
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "Recorded synthetic summary"
        let theme = try store.createTheme(name: "Rates", at: at)
        let link = try store.addArticle(article.id, toTheme: theme.id, at: at)
        let question = try store.addQuestion(themeID: theme.id, lens: .assumption, text: "What does this assume?", at: at)
        try store.saveAnswer(questionID: question.id, answer: "My private answer", at: at)
        let review = AIPackageReview(store: store, now: { at })
        let launcher = ProbeLauncher()
        let root = library.directory.appending(path: "handoff")
        let controller = ClaudeHandoffController(directory: root, review: review, launcher: launcher, now: { at })
        store.onContentPolicyChanged = { [weak store, weak controller] in if let store { controller?.reconcile(with: store, at: at) } }
        try review.build(selections: [.themeArticle(link.key)], theme: AIThemeRequest(themeID: theme.id, includeQuestions: true, includeAnswers: true), language: "English", at: at)
        let package = try #require(review.package)
        let file = try HandoffFiles.write(package, directory: root)
        return (library, store, theme, link, question, controller, file.deletingLastPathComponent(), launcher)
    }

    @Test func aCopyWithAnswersIsRemovedWhenItsThemeAQuestionOrASourceIsDeleted() async throws {
        let at = Date.now
        for removal in 0..<3 {
            let (library, store, theme, link, question, controller, folder, _) = try themeCopy(at); defer { library.cleanup() }
            #expect(FileManager.default.fileExists(atPath: folder.path))
            controller.reconcile(with: store, at: at)
            #expect(FileManager.default.fileExists(atPath: folder.path))                  // nothing was removed yet
            switch removal {
            case 0: try store.deleteTheme(id: theme.id)
            case 1: try store.deleteQuestion(id: question.id, at: at)
            default: try store.removeArticle(link.articleID, fromTheme: theme.id, at: at)
            }
            #expect(!FileManager.default.fileExists(atPath: folder.path), "removal \(removal)")
            #expect(controller.maintenanceError == nil)
        }
    }

    @Test func editingAnAnswerOrRenamingTheThemeKeepsTheCopyUntilItExpires() throws {
        let at = Date.now
        let (library, store, theme, _, question, controller, folder, _) = try themeCopy(at); defer { library.cleanup() }
        try store.saveAnswer(questionID: question.id, answer: "Edited later", at: at)
        try store.renameTheme(id: theme.id, to: "Renamed", at: at)
        controller.reconcile(with: store, at: at)
        #expect(FileManager.default.fileExists(atPath: folder.path))
        let text = try String(contentsOf: folder.appending(path: "Feeeder-review.txt"), encoding: .utf8)
        #expect(text.contains("My private answer") && !text.contains("Edited later"))      // a labelled snapshot, as promised
        controller.reconcile(with: store, at: at.addingTimeInterval(86_401))
        #expect(!FileManager.default.fileExists(atPath: folder.path))                       // the 24-hour limit still applies
    }

    @Test func aThemeCopyIsOpenedOnlyAfterItsPackageIsStillValid() async throws {
        let at = Date.now
        let (library, store, _, _, question, controller, _, launcher) = try themeCopy(at); defer { library.cleanup() }
        let review = AIPackageReview(store: store, now: { at })
        let theme = try #require(store.themes.first)
        let link = try #require(store.themeArticles.first)
        try review.build(selections: [.themeArticle(link.key)], theme: AIThemeRequest(themeID: theme.id, includeQuestions: true, includeAnswers: true), language: "English", at: at)
        let second = ClaudeHandoffController(directory: library.directory.appending(path: "handoff2"), review: review, launcher: launcher, now: { at })
        let package = try #require(review.package)
        try store.saveAnswer(questionID: question.id, answer: "Changed after review", at: at)
        await second.open(package: package)
        #expect(launcher.urls.isEmpty && second.error != nil && !second.opened)            // changed after review: nothing is opened
    }

    @Test func copiesFromOlderVersionsWithoutThemeFieldsStillReconcile() throws {
        let at = Date.now
        let (library, store, _, link, _, controller, folder, _) = try themeCopy(at); defer { library.cleanup() }
        let metadataFile = folder.appending(path: "metadata.json")
        var metadata = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: metadataFile)) as? [String: Any])
        metadata.removeValue(forKey: "themeID"); metadata.removeValue(forKey: "questionIDs")
        try JSONSerialization.data(withJSONObject: metadata).write(to: metadataFile)
        controller.reconcile(with: store, at: at)
        #expect(FileManager.default.fileExists(atPath: folder.path) && controller.maintenanceError == nil)
        try store.removeArticle(link.articleID, fromTheme: store.themes[0].id, at: at)
        #expect(!FileManager.default.fileExists(atPath: folder.path))                       // the source rule still applies to it
    }
```

(The last test needs `themeCopy`'s `link` to be the saved-summary source, which it is.)

- [ ] **Step 2: Run the tests to see them fail**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ClaudeHandoffTests`
Expected: the removal test fails (a copy survives `deleteTheme`/`deleteQuestion`) and the metadata test fails to find the fields.

- [ ] **Step 3: Implement**

`HandoffFiles.Metadata` gets two optional fields (so older copies decode):

```swift
        let themeID: UUID?
        let questionIDs: [UUID]?
```

`writeFiles` fills them from the package: `themeID: package.theme?.themeID, questionIDs: package.theme?.questions.map(\.id)`.

`reconcile` takes the new check; its closure body starts with the theme rule:

```swift
    public static func reconcile(directory: URL, validInputExpiries: [AIInputSelection: Date],
                                 themeContextIsValid: (UUID, [UUID]) -> Bool = { _, _ in true }, at: Date) throws {
        try maintain(directory: directory) { folder, record in
            var metadata = record
            if let themeID = metadata.themeID, !themeContextIsValid(themeID, metadata.questionIDs ?? []) {
                try manager.removeItem(at: folder); return
            }
            // ... the existing body, unchanged ...
```

`ClaudeHandoffController.reconcile(with:at:)` passes the check:

```swift
            try HandoffFiles.reconcile(directory: directory, validInputExpiries: expiries, themeContextIsValid: { themeID, questionIDs in
                store.theme(id: themeID) != nil && Set(questionIDs).isSubset(of: Set(store.questions(themeID: themeID).map(\.id)))
            }, at: at)
```

In `Themes.swift`, call the existing hook after each of the three deletions succeeds (inside the existing methods, after `try save(); try reload()`): `deleteTheme` (only if the theme existed), `removeArticle` (only if a link was removed), `deleteQuestion` (only if one was removed). Add one comment on the hook in `ReaderStore.swift`: it is called when something a review or a managed copy may contain is deleted or removed, not only for content policy.

```swift
        try save(); try reload()
        onContentPolicyChanged?()
```

- [ ] **Step 4: Run the tests and check them with mutations**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build` → all pass. Commit, then mutations (restore by targeted replacement): (a) drop the `themeContextIsValid` check in `HandoffFiles.reconcile` → the removal test fails for the theme and question cases; (b) remove the hook call from `deleteQuestion` → only the question case fails; (c) make `reconcile` also delete on answer edits (compare a stored hash) → `editingAnAnswerOrRenaming…` fails.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReaderCore Tests/ReaderCoreTests/ClaudeHandoffTests.swift
git commit -m "feat: remove a managed Claude copy when its theme, question, or source is deleted"
```

---

### Task 3: The entry point and the review screen

**Files:**
- Modify: `Sources/RSSReader/AIReviewView.swift`, `Sources/RSSReader/ReaderView.swift`

**Interfaces:**
- Consumes: Task 1 (`AIThemeRequest`, `review.build(selections:theme:language:at:)`), Task 2
- Produces: `AIReviewView(store:review:handoff:selections:themeID:)` (`themeID` defaults to nil); a toolbar button and sheet in `ReaderView`

- [ ] **Step 1: The review screen**

Add the property and state:

```swift
    var themeID: UUID? = nil
    @State private var includeQuestions = true
    @State private var includeAnswers = false
```

Extend the second `init` with `themeID: UUID? = nil` and assign it. Below the language row, when `themeID` is set, add:

```swift
            if let themeID {
                let hasQuestions = !store.questions(themeID: themeID).isEmpty
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("問いを含める", isOn: $includeQuestions).disabled(!hasQuestions)
                    Toggle("自分の答えと根拠の記事を含める", isOn: $includeAnswers).disabled(!hasQuestions || !includeQuestions)
                    Text(hasQuestions ? "答えは自分で書いた文章です。含めると、確認した内容のとおり、この Mac の外（Claude）へ渡ります。" : "このテーマには問いがありません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
```

(English gloss of the labels: "Include the questions", "Include my answers and the evidence articles", and the note "Answers are your own writing. If you include them, they go outside this Mac (to Claude), exactly as shown below.")

`generate()` passes the request, and a change of either switch regenerates:

```swift
    private var themeRequest: AIThemeRequest? {
        themeID.map { AIThemeRequest(themeID: $0, includeQuestions: includeQuestions && !store.questions(themeID: $0).isEmpty, includeAnswers: includeAnswers && includeQuestions) }
    }
    private func generate() {
        copied = false; error = nil; handoff.resetStatus()
        perform { try review.build(selections: options.map(\.id).filter { selected.contains($0) }, theme: themeRequest, language: language, at: .now) }
    }
```

and `.onChange(of: includeQuestions) { _, _ in generate() }`, `.onChange(of: includeAnswers) { _, _ in generate() }` next to the language `onChange`. In the `store.contentRevision` `onChange`, nothing else is needed (the review re-checks itself in `reconcile`). Replace the screen's title with `themeID == nil ? "AIへの入力を確認" : "Claudeへ渡す内容を確認"` (Review what goes to Claude).

- [ ] **Step 2: The entry in the theme view**

In `ReaderView`, add `@State private var reviewingTheme = false`, a toolbar item, a sheet, and a helper:

```swift
            ToolbarItem(placement: .primaryAction) {
                if case .theme(let id) = scope {
                    Button { reviewingTheme = true } label: { Image(systemName: "paperplane") }
                        .help("Claudeで開く…").accessibilityLabel("Claudeで開く")
                        .disabled(claudeSelections(themeID: id).isEmpty)
                }
            }
```

```swift
    /// Every theme article as two choices: the retained article text first (so it is the default), then the saved RSS summary.
    private func claudeSelections(themeID: UUID) -> [AIInputSelection] {
        store.themeArticles.filter { $0.themeID == themeID }
            .sorted { $0.addedAt != $1.addedAt ? $0.addedAt > $1.addedAt : $0.key < $1.key }
            .flatMap { link -> [AIInputSelection] in
                (store.article(id: link.articleID) == nil ? [] : [.article(link.articleID)]) + [.themeArticle(link.key)]
            }
    }
```

The sheet goes on the **sidebar modifier chain** with the other dialogs, just before `.alert("新しいテーマ", isPresented: $creatingTheme)` (the main chain is near the type-checker limit; PR 4):

```swift
        .sheet(isPresented: $reviewingTheme) {
            if case .theme(let id) = scope {
                AIReviewView(store: store, review: aiReview, handoff: handoff, selections: claudeSelections(themeID: id), themeID: id)
            }
        }
```

Disabled rule: the button is disabled only when no theme article can be a source (`AIReviewView` shows each option as unavailable when its text is gone). If every option is unavailable the review screen says so and nothing can be sent.

- [ ] **Step 3: Build and run everything**

Run: `swift build --scratch-path /private/tmp/feeeder-dogfooding-build`, `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`, `bash scripts/build-app.sh release`, `codesign --verify --deep --strict .build/Feeeder.app`, `git diff --check`. Check there is no `Binding` setter that is a method reference: `grep -rn "set: [a-zA-Z]*)" Sources/RSSReader | grep -v "set: {"`.
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/RSSReader
git commit -m "feat: add Open in Claude to the theme view, with switches for questions and answers"
```

---

### Task 4: Documents, live check, review, PR

**Files:**
- Modify: `docs/specification.md`, `docs/architecture.md`, `README.md`, `docs/user-guide.md`, `docs/user-guide.ja.md`, `docs/decisions/README.md`
- Create: `docs/decisions/0012-claude-handoff-from-themes.md`, `docs/verification/2026-10-10-claude-handoff-theme.md`

- [ ] **Step 1: Decision record 0012 (English)**

Same shape as 0010/0011 (status: valid, approved by merging the PR 8 plan; date; decider). Decisions: the seven points above. Impact: the package text now has a theme section; `AIThemeContext` is compared on every reconcile; managed copies record `themeID` and `questionIDs`; the three deletions call the existing hook. Unverified: Claude Desktop beyond 2.19675.0 / Pro / Cowork; whether Cowork reads a TXT that contains a theme section as intended; the quality of Claude's review.

- [ ] **Step 2: Update the specification, architecture, README, and both user guides**

- `docs/specification.md` (Japanese, edit in place): in the banner, move "テーマからのClaude連携" from not implemented to implemented, with a link to decision 0012. In §5.2 keep the existing text; add one sentence that the entry is a button in the theme view and that answers are off by default. PRD-05: no change to the rule; it is now implemented.
- `docs/architecture.md` §3.2: add the theme section, the re-check in `reconcile`, the metadata fields, and the deletion rule (and that answer edits do not delete a copy).
- `README.md`: the Claude hand-off line says the entry is in the theme view.
- `docs/user-guide.md` and `docs/user-guide.ja.md` §6: remove "The current build has no entry point". Describe the button, the switches and their defaults, what the screen shows, which things delete a managed copy (a deleted theme, question, or source) and which do not (an edited answer), and that the person confirms the attachment and sends. Keep the checked-versions warning. Update both files in the same commit.

- [ ] **Step 3: Live check on a synthetic instance**

Follow AGENTS.md: a separate-bundle-ID copy under `/private/tmp`, a temporary `--data-directory`, a store with a theme (three articles with summaries, two questions, one answered with evidence) written by a throwaway test that is not committed; confirm with `pgrep -fl RSSReader` that the instance's arguments contain the temporary directory; grant computer-use access only to that bundle ID; never touch `/Applications/Feeeder.app`. Check, and **do not press 「Claudeで開く」 inside the review screen** (it would open the real Claude Desktop): (1) the toolbar button appears for a theme and is disabled for an empty theme; (2) the review screen lists each article with its choices, the preview shows the theme section, answers are absent while the answers switch is off and present when it is on, the byte count and SHA-256 change; (3) "全文をコピー" (copy all) puts the same text on the clipboard (read it back); (4) "TXTを書き出す" is not needed. Background input may not reach switches inside a sheet; use the accessibility press on the switch elements, and say what could not be reached. Quit only the verified synthetic process and delete the temporary directories afterwards.

- [ ] **Step 4: Verification record (English)**

`docs/verification/2026-10-10-claude-handoff-theme.md`: environment, automated results (all tests, release build, signature, `git diff --check`, each mutation), live check results, independent review and what was done about it, and **what is not verified**: Claude Desktop beyond the checked version, whether the Cowork route reads the new section as intended, the review's usefulness, the real launch from this screen, IME and VoiceOver, macOS 26 CI.

- [ ] **Step 5: Final checks and independent review**

Run the full tests, the release build, the signature check, and `git diff --check`. This PR writes files that hold the person's own words and deletes files, so a fixed commit goes to an independent reviewer on the most capable model (read only; `docs/review-checklist.md`). Focus: whether anything the person did not choose can reach the package, file, copy, or export (answers when off, "current understanding", evidence of questions); the re-check and its equality (ordering, whitespace, themes renamed); the removal rules and the hook (re-entrancy: `onContentPolicyChanged` runs inside a store write); legacy and damaged metadata; marker text in user content; the split export; tests that would survive mutations. Fix Critical and Important findings test-first.

- [ ] **Step 6: Push and open the PR**

Push `claude/claude-handoff-theme` and open the PR without asking (standing instruction). The body says what is not included (no new launch path, no Chat route, no "current understanding" in the package, no automatic send or reply), the verification, and what is unverified. If CI fails, suspect first a compiler crash on Swift 6.3.3 (method references as setters) or a mutable capture in a `@MainActor` closure in tests. Do not merge.

---

## Self-review

**Spec coverage** (§5.2, PRD-05, §3.3): choose the language, the sources one by one, questions, answers → Task 1, 3. Show answers on the review screen → the preview is the package text → Task 1, 3. Distinguish saved summaries from retained articles; show saved date, coverage, URLs → existing, reused in Task 3. One source means an article-level request → choose a single option in the same screen. Managed-copy lifetime and deletion sync → Task 2. Failure paths (cancel, launch failure, copy, export, split) → existing, kept; the split export is covered for the theme section. Only the Cowork route → no change to the launch.

**Type consistency:** `AIThemeRequest` and `AIThemeContext` are defined in Task 1 and used in Tasks 2 and 3. `AIPackage.theme` (Task 1) is read by `HandoffFiles.writeFiles` (Task 2). `themeContextIsValid` (Task 2) is passed by the controller. `claudeSelections` and `themeID` (Task 3) use only existing store API.

**Placeholder scan:** none. One place says to reorder the arguments of `AIThemeContext(...)` to the property order (Task 1 store function); the exact order is given there.

**Pre-checked code.** I applied the code and tests of Tasks 1 to 3 to the working tree before writing the final text (Swift 6.4, macOS 27.0.1), then removed them again. The tests for Tasks 1 and 2 pass (193 tests in the whole suite), and the app, including the sheet and the toolbar button, builds. The sheet works on the sidebar chain without a type-checker problem. Not checked yet: the live behaviour of the review screen (Task 4), and everything on CI (macOS 26 / Swift 6.3.3).

