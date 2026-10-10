import Foundation
import Testing
@testable import ReaderCore

@MainActor struct NoteActionModelTests {
    let note = "# 見出し\n金利が上がると返済が増える。分からない。\n\n# 次\n別の節。"
    var inFirst: NSRange { NSRange(location: 8, length: 0) }
    var inSecond: NSRange { NSRange(location: (note as NSString).length - 2, length: 0) }

    private func settle(_ model: NoteActionModel) async {
        for _ in 0..<300 { if case .working = model.state { try? await Task.sleep(for: .milliseconds(10)) } else { return } }
    }
    private func make(_ assistant: FakeAssistant, enabled: SuggestionSwitch = SuggestionSwitch(), deadline: Double = 5) -> NoteActionModel {
        NoteActionModel(assistant: assistant, isEnabled: { enabled.on }, deadline: deadline)
    }

    @Test func aRewriteCardIsMadeOnlyAfterTheRequestAndCarriesItsTarget() async throws {
        let assistant = FakeAssistant(); await assistant.scriptGeneration(["「読みやすい文章。」"])
        let model = make(assistant)
        let early = await assistant.generateCalls
        #expect(model.state == .idle && early.isEmpty)
        model.request(.clearer, note: note, selection: inFirst, goal: "金利を学ぶ")
        #expect(model.state == .working(.clearer))
        await settle(model)
        guard case .ready(let card) = model.state else { Issue.record("got \(model.state)"); return }
        #expect(card.answer == "読みやすい文章。" && card.action == .clearer && card.noteText == note && card.selection == inFirst)
        #expect(card.target.text == "金利が上がると返済が増える。分からない。" && !card.wasCut)
        let calls = await assistant.generateCalls
        #expect(calls.count == 1 && !calls[0].prompt.contains("金利を学ぶ"))
    }

    @Test func theEssenceCardHasThreeBulletLinesAndSeesTheGoal() async throws {
        let assistant = FakeAssistant(); await assistant.scriptGeneration(["1. 一\n2. 二\n3. 三\n4. 四"])
        let model = make(assistant)
        model.request(.essence, note: note, selection: inFirst, goal: "金利を学ぶ")
        await settle(model)
        guard case .ready(let card) = model.state else { Issue.record("got \(model.state)"); return }
        #expect(card.answer == "・一\n・二\n・三")
        let calls = await assistant.generateCalls
        #expect(calls[0].prompt.contains("学習ゴール: 金利を学ぶ"))
    }

    @Test func nothingIsCalledWhenOffUnavailableTooLongOrEmpty() async throws {
        let off = SuggestionSwitch(); off.on = false
        let a1 = FakeAssistant(); await a1.scriptGeneration(["x"])
        let m1 = make(a1, enabled: off); m1.request(.clearer, note: note, selection: inFirst, goal: "")
        #expect(m1.state == .unavailable(.disabled))
        for (availability, reason) in [(AssistantAvailability.unsupported, NoteActionModel.Reason.unsupported), (.assetsMissing, .assetsMissing)] {
            let a = FakeAssistant(); await a.scriptGeneration(["x"], availability: availability)
            let m = make(a); m.request(.clearer, note: note, selection: inFirst, goal: "")
            await settle(m)
            #expect(m.state == .unavailable(reason))
            let calls = await a.generateCalls
            #expect(calls.isEmpty)
        }
        let a2 = FakeAssistant(); await a2.scriptGeneration(["x"])
        let long = "# 長い\n" + String(repeating: "あ", count: 1_301)
        let m2 = make(a2); m2.request(.clearer, note: long, selection: NSRange(location: 6, length: 0), goal: "")
        #expect(m2.state == .unavailable(.tooLong))
        m2.request(.clearer, note: "# 空\n", selection: NSRange(location: 1, length: 0), goal: "")
        #expect(m2.state == .unavailable(.noText))
        let none = NoteActionModel(assistant: nil, isEnabled: { true })
        none.request(.clearer, note: note, selection: inFirst, goal: "")
        #expect(none.state == .unavailable(.unsupported))
        let made = await a2.generateCalls
        #expect(made.isEmpty)
    }

    @Test func aFailureABlankAnswerAndTheDeadlineAreFailedAndRecoverable() async throws {
        let failing = FakeAssistant(); await failing.scriptGeneration(failure: CocoaError(.fileReadUnknown))
        let one = make(failing); one.request(.clearer, note: note, selection: inFirst, goal: ""); await settle(one)
        #expect(one.state == .failed)
        let blank = FakeAssistant(); await blank.scriptGeneration(["  \u{200B}\n"])
        let two = make(blank); two.request(.essence, note: note, selection: inFirst, goal: ""); await settle(two)
        #expect(two.state == .failed)
        let slow = FakeAssistant(); await slow.scriptGeneration(["遅い"], hold: true)
        let three = make(slow, deadline: 0.05); three.request(.clearer, note: note, selection: inFirst, goal: ""); await settle(three)
        #expect(three.state == .failed)
        await slow.releaseGeneration(); await slow.scriptGeneration(["次は成功"])
        three.request(.clearer, note: note, selection: inFirst, goal: ""); await settle(three)
        if case .ready(let card) = three.state { #expect(card.answer == "次は成功") } else { Issue.record("got \(three.state)") }
    }

    @Test func turningTheSettingOffWhileWorkingDropsTheAnswer() async throws {
        let assistant = FakeAssistant(); await assistant.scriptGeneration(["答え"], hold: true)
        let enabled = SuggestionSwitch()
        let model = make(assistant, enabled: enabled)
        model.request(.clearer, note: note, selection: inFirst, goal: "")
        while !(await assistant.generationParked) { try await Task.sleep(for: .milliseconds(5)) }
        enabled.on = false
        await assistant.releaseGeneration(); await settle(model)
        #expect(model.state == .unavailable(.disabled))
    }

    @Test func aChangedNoteOrSelectionDropsTheCardAndTheRunningRequest() async throws {
        let assistant = FakeAssistant(); await assistant.scriptGeneration(["一", "二"])
        let model = make(assistant)
        model.request(.clearer, note: note, selection: inFirst, goal: ""); await settle(model)
        model.noteDidChange(note: note, selection: inFirst)                             // nothing changed
        #expect(model.currentCard(note: note, selection: inFirst) != nil)
        model.noteDidChange(note: note, selection: inSecond)                            // the cursor moved to another section
        #expect(model.state == .idle && model.currentCard(note: note, selection: inFirst) == nil)
        model.request(.clearer, note: note, selection: inFirst, goal: ""); await settle(model)
        model.noteDidChange(note: note + "。", selection: inFirst)                       // one character typed
        #expect(model.state == .idle)

        let held = FakeAssistant(); await held.scriptGeneration(["遅れた答え"], hold: true)
        let working = make(held)
        working.request(.clearer, note: note, selection: inFirst, goal: "")
        while !(await held.generationParked) { try await Task.sleep(for: .milliseconds(5)) }
        working.noteDidChange(note: note, selection: inFirst)                           // same: keeps working
        #expect(working.state == .working(.clearer))
        working.noteDidChange(note: note, selection: inSecond)
        #expect(working.state == .idle)
        await held.releaseGeneration()                                                  // a call that ignores cancellation answers late
        try await Task.sleep(for: .milliseconds(100))
        #expect(working.state == .idle)
    }

    @Test func currentCardRequiresTheExactNoteAndSelection() async throws {
        let assistant = FakeAssistant(); await assistant.scriptGeneration(["答え"])
        let model = make(assistant)
        model.request(.essence, note: note, selection: inFirst, goal: ""); await settle(model)
        #expect(model.currentCard(note: note, selection: inFirst) != nil)
        #expect(model.currentCard(note: note + " ", selection: inFirst) == nil)
        #expect(model.currentCard(note: note, selection: NSRange(location: 9, length: 0)) == nil)
        #expect(model.currentCard(note: note, selection: NSRange(location: 8, length: 1)) == nil)
    }

    @Test func aSecondRequestAndCancelAndResetDropOlderAnswers() async throws {
        let assistant = FakeAssistant(); await assistant.scriptGeneration(["一つ目", "二つ目"], hold: true)
        let model = make(assistant)
        model.request(.clearer, note: note, selection: inFirst, goal: "")
        while !(await assistant.generationParked) { try await Task.sleep(for: .milliseconds(5)) }
        model.cancel()
        #expect(model.state == .idle)
        await assistant.releaseGeneration()
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.state == .idle)
        model.request(.clearer, note: note, selection: inFirst, goal: "")
        while !(await assistant.generationParked) { try await Task.sleep(for: .milliseconds(5)) }
        model.request(.essence, note: note, selection: inFirst, goal: "")               // replaces the running one
        try await Task.sleep(for: .milliseconds(50))
        await assistant.releaseGeneration()
        await settle(model); try await Task.sleep(for: .milliseconds(100))
        if case .ready(let card) = model.state { #expect(card.action == .essence) } else { Issue.record("got \(model.state)") }
    }
}
