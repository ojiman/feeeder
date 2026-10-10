import Testing
@testable import ReaderCore

struct HandoffDefaultsTests {
    @Test func theToolbarEntryOffersTheGoalAndLeavesTheNoteOff() {
        let s = HandoffDefaults.switches(goal: "学ぶこと", note: "ノート", fromNotePanel: false)
        #expect(s == .init(goalOn: true, noteOn: false, goalEnabled: true, noteEnabled: true))
    }
    @Test func theNotePanelsButtonSwitchesBothOn() {
        let s = HandoffDefaults.switches(goal: "学ぶこと", note: "ノート", fromNotePanel: true)
        #expect(s == .init(goalOn: true, noteOn: true, goalEnabled: true, noteEnabled: true))
    }
    @Test func anEmptyGoalOrNoteIsOffAndDisabledWhateverTheEntry() {
        for fromPanel in [false, true] {
            #expect(HandoffDefaults.switches(goal: "", note: "ノート", fromNotePanel: fromPanel) == .init(goalOn: false, noteOn: fromPanel, goalEnabled: false, noteEnabled: true))
            #expect(HandoffDefaults.switches(goal: "目標", note: " \n ", fromNotePanel: fromPanel) == .init(goalOn: true, noteOn: false, goalEnabled: true, noteEnabled: false))
            #expect(HandoffDefaults.switches(goal: " ", note: "", fromNotePanel: fromPanel) == .init(goalOn: false, noteOn: false, goalEnabled: false, noteEnabled: false))
        }
    }
}
