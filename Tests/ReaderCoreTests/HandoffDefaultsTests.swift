import Testing
@testable import ReaderCore

struct HandoffDefaultsTests {
    @Test func theToolbarEntryLeavesTheNoteOff() {
        #expect(HandoffDefaults.switches(note: "ノートの本文", fromNotePanel: false) == .init(noteOn: false, noteEnabled: true))
    }
    @Test func theNotePanelsButtonSwitchesTheNoteOn() {
        #expect(HandoffDefaults.switches(note: "ノートの本文", fromNotePanel: true) == .init(noteOn: true, noteEnabled: true))
    }
    @Test func anEmptyNoteIsOffAndDisabledWhateverTheEntry() {
        for fromNotePanel in [false, true] {
            #expect(HandoffDefaults.switches(note: "", fromNotePanel: fromNotePanel) == .init(noteOn: false, noteEnabled: false))
            #expect(HandoffDefaults.switches(note: " \n\t ", fromNotePanel: fromNotePanel) == .init(noteOn: false, noteEnabled: false))
        }
    }
}
