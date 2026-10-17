import Testing
@testable import ReaderCore

// Specification 3.7: the shortcut list is made from the keys the reader handles.
@Suite(EnglishLanguage()) struct ReaderShortcutsTests {
    @Test func everyReadingLetterIsInTheList() {
        let listed = Set(ReaderShortcuts.rows.flatMap(\.keys))
        for letter in ReaderShortcuts.readingLetters { #expect(listed.contains(letter), "\(letter) is not in the shortcut list") }
    }

    @Test func everyLetterInTheListIsHandled() {
        let letters = ReaderShortcuts.rows.flatMap(\.keys).filter { $0.count == 1 }
        for letter in letters { #expect(ReaderShortcuts.readingLetters.contains(letter), "\(letter) is listed but not handled") }
    }

    @Test func theGroupsAreInTheOrderOfTheSpecification() {
        #expect(ReaderShortcuts.Group.allCases.map(\.title) == ["Reading", "List", "Original Page", "Note"])
        for group in ReaderShortcuts.Group.allCases { #expect(!ReaderShortcuts.rows(in: group).isEmpty) }
        #expect(Set(ReaderShortcuts.rows.map(\.id)).count == ReaderShortcuts.rows.count)
    }

    @Test func theNotesKeysAreListed() {
        let note = ReaderShortcuts.rows(in: .note).flatMap(\.keys)
        #expect(note.contains("n") && note.contains("⌥⌘I") && note.contains("c") && note.contains("⌥⌘↑") && note.contains("Esc"))
    }
}
