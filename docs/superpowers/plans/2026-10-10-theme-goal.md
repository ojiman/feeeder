# N1: Learning goal for a theme — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This project keeps one supervised implementer ([decision 0002](../../decisions/0002-single-supervised-writer.md)).

**Goal:** A theme gets a learning goal (what the person wants to learn in it). The person can write it when creating a theme and edit it later, and it is shown at the top of the theme on both faces.

**Architecture:** One new stored field, `Theme.goal`, with a store function that changes the name and the goal in one save. One sheet replaces the two name alerts (new theme, rename). A one-line "goal" strip sits under the face switch, on the Articles face and on the Questions face. No AI uses the goal yet (that starts in N4/N5).

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing. No new dependency.

**Spec:** [decision 0013](../../decisions/0013-goal-and-note-for-themes.md) (point 1), [roadmap Part 1c](2026-10-10-theme-notes.md), PRD §3.2 (theme) and PRD-04. Merging this plan approves it. Plan approval is not product acceptance.

**Language:** New project text is in English (AGENTS.md, "Language"). App labels stay Japanese; they are quoted as they appear, with a short English gloss.

## Decisions for you (merging approves them)

1. **Limit and form.** The goal is plain text, at most 200 characters (counted as characters, so one emoji or one kanji counts as 1), may be empty. Line breaks become spaces (one paragraph), the same as other one-line fields. A goal longer than 200 characters is **refused with a message, never cut silently**. The editor stops the person from typing past 200 and shows a counter ("120/200").
2. **One sheet, not two alerts.** 「新しいテーマ」 (New Theme) and 「名前を変更」 (Rename) become one sheet, 「テーマ」 (Theme), with two fields: name and goal. The context menu item 「名前を変更…」 becomes 「名前とゴールを編集…」 (Edit Name and Goal…). Creating a theme from the `t` picker or from a group of Stars is unchanged (name only, goal empty). The person can add the goal later.
3. **Where the goal is shown.** Under the face switch at the top of the middle column, on both faces, in at most two lines in a secondary color. When the goal is empty it shows 「ゴールを書く…」 (Write a goal…) as a quiet link. Clicking either opens the same sheet.
4. **Not in this PR.** The goal is not sent to Claude (that is N6) and is not used by AI (N4, N5). The sidebar does not show the goal. The questions and answers are untouched (N2 replaces them).
5. **Older libraries.** A library written before this change opens as it is: existing themes get an empty goal. This is a defaulted new field (a lightweight SwiftData change). I will check it by opening a store written by the current `main` with the new code (Task 1, Step 6), and say so in the PR.

## Global Constraints

- Support floor macOS 27.0; build floor and CI stay macOS 26.6 / Swift 6.3.3. No macOS 27-only API.
- Every store function that writes starts with `reloadIfNeeded()`, and its failure paths are in the failure-injection lists (`failedSaveLeavesNoPartialThemeStateAndCanBeRetried`, `eachThemeChangeRecoversOnItsFirstCallAfterReloadSucceeds`). A failed save is never shown as success; text the person typed is never dropped silently.
- No `Binding` setter that is a method reference; no mutated captured `var` in `@MainActor` closures in tests (Swift 6.3.3 on CI fails on both).
- Tests use synthetic data and temporary databases only. Do not read the person's library.
- One theme per PR. Failing tests first. Commit and PR text in English. Add the attribution line the session gives.
- The specification and the architecture are updated in the same PR (AGENTS.md, Definition of done 6). Do not push to `main`, sign, or release. After implementation, push the branch and open the PR without asking (standing instruction).

## Review Focus

1. A goal over 200 characters, with emoji, with combining characters, with only spaces or line breaks, pasted with a line break → Task 1.
2. Editing the name and goal together: a blank name with a good goal changes nothing; a failed save keeps the sheet's text so the person can retry → Task 1, Task 2.
3. The theme is deleted or renamed elsewhere while the sheet is open (stale ID) → Task 1 (missing theme), Task 2.
4. An older library opens with empty goals → Task 1, Step 6.

---

### Task 1: The field, the store function, the tests

**Files:**
- Modify: `Sources/ReaderCore/Themes.swift`
- Test: `Tests/ReaderCoreTests/ThemeTests.swift`

**Interfaces:**
- Consumes: `SingleLineText.name(_:)`, `ReaderStore.reloadIfNeeded()`, `save()`, `reload()`, `theme(id:)`.
- Produces: `Theme.goal: String` (default `""`), `Theme.goalLimit = 200`, `ThemeError.goalTooLong`, `ReaderStore.createTheme(name:goal:at:)`, `ReaderStore.updateTheme(id:name:goal:at:)`.

- [ ] **Step 1: Write the failing tests** (add to `ThemeTests`; `at`, `TestLibrary`, and the failure-injection helpers already exist)

```swift
    @Test func aGoalIsSavedTrimmedOnOneLineAndKeptAfterReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let themeID = try {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let theme = try store.createTheme(name: "Rates", goal: "  Understand how rates\naffect households  ", at: at)
            #expect(theme.goal == "Understand how rates affect households")
            return theme.id
        }()
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.theme(id: themeID)?.goal == "Understand how rates affect households")
        #expect(try ReaderStore(url: library.url, now: at).createTheme(name: "Empty goal", at: at).goal.isEmpty)
    }

    @Test func theGoalLimitIsInCharactersAndALongGoalIsRefusedNotCut() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let exact = String(repeating: "学", count: Theme.goalLimit)
        #expect(try store.createTheme(name: "A", goal: exact, at: at).goal == exact)
        let emoji = String(repeating: "👨‍👩‍👧", count: Theme.goalLimit)                 // 200 characters, many scalars
        #expect(try store.createTheme(name: "B", goal: emoji, at: at).goal == emoji)
        #expect(throws: ThemeError.self) { try store.createTheme(name: "C", goal: exact + "学", at: at) }
        let before = store.themes.count
        #expect(throws: ThemeError.self) { try store.createTheme(name: "D", goal: exact + "学", at: at) }
        #expect(store.themes.count == before)                                          // nothing was created
    }

    @Test func editingNameAndGoalTogetherIsOneChangeAndRejectsBadInput() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "Old", goal: "Old goal", at: at)
        try store.updateTheme(id: theme.id, name: " New\nname ", goal: " New goal ", at: at.addingTimeInterval(5))
        #expect(theme.name == "New name" && theme.goal == "New goal" && theme.updatedAt == at.addingTimeInterval(5))
        try store.updateTheme(id: theme.id, name: "New name", goal: "", at: at.addingTimeInterval(6))   // clearing the goal is allowed
        #expect(theme.goal.isEmpty)
        let stamp = theme.updatedAt
        try store.updateTheme(id: theme.id, name: "New name", goal: "", at: at.addingTimeInterval(9))   // nothing changed
        #expect(theme.updatedAt == stamp)
        #expect(throws: ThemeError.self) { try store.updateTheme(id: theme.id, name: " \n ", goal: "A good goal", at: at) }
        #expect(throws: ThemeError.self) { try store.updateTheme(id: theme.id, name: "Name", goal: String(repeating: "x", count: 201), at: at) }
        #expect(throws: ThemeError.self) { try store.updateTheme(id: UUID(), name: "Name", goal: "Goal", at: at) }
        #expect(theme.name == "New name" && theme.goal.isEmpty)                         // a rejected edit changes nothing
    }
```

Add the new functions to the two failure-injection tests, next to the existing `renameTheme` lines:

```swift
        // failedSaveLeavesNoPartialThemeStateAndCanBeRetried (after the renameTheme check)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.updateTheme(id: theme.id, name: "失われる名前", goal: "失われるゴール", at: at) }
        #expect(store.theme(id: theme.id)?.name == "成功" && store.theme(id: theme.id)?.goal == "")
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createTheme(name: "失われる", goal: "ゴール", at: at) }
        #expect(store.themes.count == themeCount)
```

```swift
        // eachThemeChangeRecoversOnItsFirstCallAfterReloadSucceeds (after the renameTheme recovery)
        induceFailedRecovery()
        try store.updateTheme(id: themeID, name: "新しい名前", goal: "新しいゴール", at: at)
        #expect(store.theme(id: themeID)?.goal == "新しいゴール")
        induceFailedRecovery()
        let withGoal = try store.createTheme(name: "ゴールつき", goal: "回復後のゴール", at: at)
        #expect(store.theme(id: withGoal.id)?.goal == "回復後のゴール")
```

(Read the surrounding test code first. `themeCount` and `themeID` are existing local names in those tests; if a name differs, use the existing one. In the recovery test, the later checks expect an exact list of themes (`["回復後の新規"]`), so put the new `createTheme` lines **after** that final check, as the PR 8 work did.)

- [ ] **Step 2: Run the tests and see them fail.** `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests` → compile errors (`goal`, `goalLimit`, `updateTheme` do not exist).

- [ ] **Step 3: Implement**

```swift
// ThemeError: add the case and its message
    case goalTooLong
        case .goalTooLong: "ゴールは\(Theme.goalLimit)文字までです。短くしてください。"   // "The goal is at most 200 characters. Please shorten it."
```

```swift
@Model public final class Theme {
    public static let goalLimit = 200
    @Attribute(.unique) public var id: UUID
    public var name: String
    /// What the person wants to learn in this theme: plain text, one paragraph, at most `goalLimit` characters, may be empty.
    public var goal: String = ""
    // ... the rest is unchanged
```

```swift
    /// The goal as it is saved: line breaks become spaces and the ends are trimmed. Never cut: too long is an error.
    private static func normalizedGoal(_ text: String) throws -> String {
        let goal = SingleLineText.name(text)
        guard goal.count <= Theme.goalLimit else { throw ThemeError.goalTooLong }
        return goal
    }

    @discardableResult public func createTheme(name: String, goal: String, at: Date) throws -> Theme {
        try reloadIfNeeded()
        let name = SingleLineText.name(name)
        guard !name.isEmpty else { throw ThemeError.missingName }
        let goal = try Self.normalizedGoal(goal)
        let theme = Theme(name: name, at: at)
        theme.goal = goal
        context.insert(theme)
        try save(); try reload()
        return theme
    }

    /// Changes the name and the goal in one save. A blank name, a too long goal, or an unknown theme changes nothing.
    public func updateTheme(id: UUID, name: String, goal: String, at: Date) throws {
        try reloadIfNeeded()
        let name = SingleLineText.name(name)
        guard !name.isEmpty else { throw ThemeError.missingName }
        let goal = try Self.normalizedGoal(goal)
        guard let theme = theme(id: id) else { throw ThemeError.missingTheme }
        guard theme.name != name || theme.goal != goal else { return }
        theme.name = name; theme.goal = goal; theme.updatedAt = at
        try save(); try reload()
    }
```

(`normalizedGoal` is `private static` inside the `ReaderStore` extension; call it as `Self.normalizedGoal`.)

- [ ] **Step 4: Run the tests** → all pass. Commit, then check by mutation (restore by replacing the line, never `git checkout` over uncommitted work): (a) change `goal.count <=` to `goal.utf16.count <=` → the emoji case fails; (b) drop `reloadIfNeeded()` from `updateTheme` → the recovery test fails; (c) skip `normalizedGoal` in `createTheme` → the long-goal case fails.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReaderCore/Themes.swift Tests/ReaderCoreTests/ThemeTests.swift
git commit -m "feat: add a learning goal to a theme, saved with the name in one change"
```

- [ ] **Step 6: Check an older library (not committed).** With the code of `main` before this change, write a throwaway test that creates a store at `/private/tmp/feeeder-n1-old` with one theme and one question (the same way earlier checks seeded stores), run it, and delete the test. Then on the new code, a throwaway test opens that path, expects `theme.goal == ""` and the question intact, sets a goal with `updateTheme`, reopens, and expects the goal. Delete both tests and the temporary directory. The result goes into the PR text (PASS or FAIL, with the environment). If it fails, stop and ask: do not delete or recreate the person's store.

---

### Task 2: The sheet and the goal strip

**Files:**
- Create: `Sources/RSSReader/ThemeEditorSheet.swift`
- Modify: `Sources/RSSReader/ReaderView.swift`, `Sources/RSSReader/ThemeViews.swift`

**Interfaces:**
- Consumes: Task 1; `Binding.singleLine()`.
- Produces: `ThemeEditorSheet(store:themeID:onSaved:)` (`themeID == nil` means create), `ThemeGoalStrip(goal:onEdit:)`.

- [ ] **Step 1: The sheet.** One sheet for both create and edit. The text stays after a failed save, with the error shown, so the person can retry.

```swift
import SwiftUI
import ReaderCore

/// New theme (themeID == nil) or edit name and goal. The text stays when a save fails.
struct ThemeEditorSheet: View {
    @Bindable var store: ReaderStore
    let themeID: UUID?
    let onSaved: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var goal = ""
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(themeID == nil ? "新しいテーマ" : "名前とゴールを編集").font(.title2.bold())
            TextField("テーマの名前", text: $name.singleLine()).focused($nameFocused).onSubmit(save)
            VStack(alignment: .leading, spacing: 4) {
                Text("学習ゴール（任意）").font(.caption).foregroundStyle(.secondary)
                TextField("このテーマで何を学びたいか", text: limitedGoal, axis: .vertical).lineLimit(2...4)
                    .accessibilityLabel("学習ゴール")
                Text("\(goal.count)/\(Theme.goalLimit)").font(.caption2.monospacedDigit())
                    .foregroundStyle(goal.count >= Theme.goalLimit ? Color.orange : Color.secondary)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存", action: save).keyboardShortcut(.defaultAction)
                    .disabled(SingleLineText.name(name).isEmpty)
            }
        }
        .padding(20).frame(width: 440)
        .onAppear {
            if let themeID, let theme = store.theme(id: themeID) { name = theme.name; goal = theme.goal }
            nameFocused = true
        }
    }

    /// Typing and pasting stop at the limit and line breaks become spaces, so a save is not refused for length.
    private var limitedGoal: Binding<String> {
        Binding(get: { goal }, set: { new in goal = String(SingleLineText.lineBreaksRemoved(new).prefix(Theme.goalLimit)) })
    }

    private func save() {
        guard !SingleLineText.name(name).isEmpty else { return }
        do {
            if let themeID { try store.updateTheme(id: themeID, name: name, goal: goal, at: .now); onSaved(themeID) }
            else { onSaved(try store.createTheme(name: name, goal: goal, at: .now).id) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
```

(Pasting more than 200 characters keeps the first 200 and the counter turns orange; this is the one place text is cut, and the person sees it happen as they paste. The store still refuses an over-long goal, so nothing is cut silently there. Say so in the PR.)

- [ ] **Step 2: Wire it in `ReaderView`.** Replace the two alerts and their state (`creatingTheme`, `newThemeName`, `renamingTheme`, `themeName`) with one optional editor target. The sheet goes on the sidebar chain next to the other dialogs (the main chain is near the type-checker limit):

```swift
    @State private var themeEditor: ThemeEditorTarget?
    private struct ThemeEditorTarget: Identifiable { let id = UUID(); let themeID: UUID? }
```

```swift
        .sheet(item: $themeEditor) { target in
            ThemeEditorSheet(store: store, themeID: target.themeID) { scope = .theme($0) }
        }
```

The sidebar's 「新しいテーマ」 button sets `themeEditor = ThemeEditorTarget(themeID: nil)`; the context menu item becomes `Button("名前とゴールを編集…") { themeEditor = ThemeEditorTarget(themeID: theme.id) }`. Remove the old alert blocks. Keep the sheet-open guard in `shortcutsEnabled` (the existing list of "a sheet is open" flags): replace `creatingTheme` and `renamingTheme` there with `themeEditor != nil`.

- [ ] **Step 3: The goal strip.** In `ThemeViews.swift`:

```swift
/// The theme's goal under the face switch. An empty goal is a quiet invitation to write one.
struct ThemeGoalStrip: View {
    let goal: String
    let onEdit: () -> Void
    var body: some View {
        Button(action: onEdit) {
            Group {
                if goal.isEmpty { Text("ゴールを書く…").foregroundStyle(.tertiary) }
                else { Text(goal).foregroundStyle(.secondary).lineLimit(2) }
            }
            .font(.caption).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 8).background(.bar)
        .accessibilityLabel(goal.isEmpty ? "学習ゴールを書く" : "学習ゴール: \(goal)")
    }
}
```

Put it under `ThemeFacePicker` in both places: the article list's top inset in `ReaderView` (`if case .theme(let id) = scope { VStack(spacing: 0) { ThemeFacePicker(...); ThemeGoalStrip(goal: store.theme(id: id)?.goal ?? "", onEdit: { themeEditor = ThemeEditorTarget(themeID: id) }) } }`) and the top inset of `ThemeQuestionsPane` (add an `onEditGoal: () -> Void` parameter and pass the same closure from `ReaderView`).

- [ ] **Step 4: Build, test, release build.** `swift build`, `swift test`, `bash scripts/build-app.sh release`, `codesign --verify --deep --strict .build/Feeeder.app`, `git diff --check`, and no method-reference `Binding` setter (`grep -rn "set: [a-zA-Z]*)" Sources/RSSReader | grep -v "set: {"`). The toolbar must keep its height when the goal strip appears (the strip is inside the content, not the toolbar).

- [ ] **Step 5: Commit**

```bash
git add Sources/RSSReader
git commit -m "feat: edit a theme's name and goal in one sheet, and show the goal at the top"
```

---

### Task 3: Documents, a short live check, review, PR

- [ ] **Step 1: Update the specification and the architecture** (the Japanese text is edited in place, minimal): PRD §3.2 says a theme has a name, a **learning goal** (up to 200 characters, optional, one paragraph), the "current understanding", articles, and questions; PRD-04 mentions writing the goal. Architecture §2.1: `Theme` has `goal` (default empty); the store function `updateTheme(id:name:goal:at:)` changes name and goal in one save. The banner of the specification says the goal is implemented (decision 0013). The user guides (both) get one sentence about the goal and the sheet.
- [ ] **Step 2: A short live check on a synthetic instance** (a separate bundle ID copy with a temporary data directory; AGENTS.md procedure; never touch `/Applications/Feeeder.app`). Check: the sheet opens for a new theme and for editing; the counter and the 200-character stop; the goal strip shows the goal and the empty invitation on both faces; clicking it opens the sheet; the window and toolbar do not jump when the strip appears. Say what could not be reached with background input.
- [ ] **Step 3: Independent review.** This changes the model and the store, so one pass on a fixed commit (read only, `docs/review-checklist.md`): the field default and older stores, the 200-character rule, `updateTheme` atomicity and failure injection, stale theme IDs in the sheet, and whether the tests would fail under mutation. No verification record is needed (AGENTS.md, Proportion); the PR text carries the results.
- [ ] **Step 4: Push and open the PR** without asking. The PR says what is not included (no AI use of the goal, not in Claude hand-off, not in the sidebar) and what is unverified (IME in the goal field, VoiceOver, macOS 26 CI result if it did not run).

---

## Self-review

**Spec coverage** (decision 0013, point 1): the theme has a name and a goal of one or two lines, at most 200 characters, may be empty, shown at the top of the theme → Task 1 (rules), Task 2 (editing and display). Not in this PR by design: use by AI (N4, N5), hand-off (N6).

**Type consistency:** `Theme.goal`, `Theme.goalLimit`, `ThemeError.goalTooLong`, `createTheme(name:goal:at:)`, and `updateTheme(id:name:goal:at:)` are defined in Task 1 and used in Task 2. `ThemeEditorSheet` and `ThemeGoalStrip` are defined in Task 2 and used in the same task.

**Placeholder scan:** none. Two places say to read the surrounding test code and use its local names (Task 1, Step 1); the names are given as `themeCount` and `themeID`.

**Pre-checked.** I applied the code of Tasks 1 and 2 (the three new store tests, the sheet, the goal strip, the wiring) to a working tree, then removed it again (Swift 6.4, macOS 27.0.1). The suite passed (203 tests), the release build passed, and the sheet and strip compile on the existing modifier chain without a type-checker problem. Not checked yet: the failure-injection additions, the older-library check (Task 1, Step 6), and everything on screen.

