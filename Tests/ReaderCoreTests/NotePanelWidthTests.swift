import Foundation
import Testing
@testable import ReaderCore

struct NotePanelWidthTests {
    private func defaults() -> (UserDefaults, String) {
        let name = "unagi-reader-test-\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test func aWidthInsideTheRangeIsKeptAndOneOutsideIsClamped() {
        // Decision 0050 point 5: 640 pt at first, up to 1,280 pt, at least 300 pt.
        #expect(NotePanelWidth.range == 300...1_280 && NotePanelWidth.defaultWidth == 640)
        #expect(NotePanelWidth.clamped(300) == 300 && NotePanelWidth.clamped(450.5) == 450.5 && NotePanelWidth.clamped(1_280) == 1_280)
        #expect(NotePanelWidth.clamped(299.9) == 300 && NotePanelWidth.clamped(0) == 300 && NotePanelWidth.clamped(-50) == 300)
        #expect(NotePanelWidth.clamped(1_280.1) == 1_280 && NotePanelWidth.clamped(10_000) == 1_280)
    }

    @Test func aMissingOrInvalidValueFallsBackToTheDefault() {
        #expect(NotePanelWidth.clamped(nil) == 640)
        #expect(NotePanelWidth.clamped(.nan) == 640 && NotePanelWidth.clamped(.infinity) == 640 && NotePanelWidth.clamped(-.infinity) == 640)
        let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
        #expect(NotePanelWidth.load(from: store) == 640)                                  // nothing saved
        store.set("wide", forKey: NotePanelWidth.key)
        #expect(NotePanelWidth.load(from: store) == 640)                                  // not a number
        store.set(Double.nan, forKey: NotePanelWidth.key)
        #expect(NotePanelWidth.load(from: store) == 640)
    }

    @Test func aSavedWidthComesBackClampedAfterARestart() {
        let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
        NotePanelWidth.save(520, to: store)
        #expect(NotePanelWidth.load(from: store) == 520)
        NotePanelWidth.save(9_999, to: store)                                             // a corrupt or old value is clamped on the way in
        #expect(NotePanelWidth.load(from: store) == 1_280)
        store.set(100.0, forKey: NotePanelWidth.key)                                       // and on the way out
        #expect(NotePanelWidth.load(from: store) == 300)
    }

    @Test func aWidthThatBarelyChangedIsNotWrittenAgain() {
        #expect(NotePanelWidth.needsSaving(new: 401, saved: 400) == false)
        #expect(NotePanelWidth.needsSaving(new: 402, saved: 400) == true)
        #expect(NotePanelWidth.needsSaving(new: 450, saved: nil) == true)
        #expect(NotePanelWidth.needsSaving(new: .nan, saved: 400) == false)
    }

    /// Only a width the person chose is kept: not the first width the layout gave the panel, and not one the layout squeezed below the
    /// minimum (a 270 pt panel in a 1,240 pt window must not turn the default into 300).
    @Test func aWidthIsKeptOnlyWhenThePersonChoseIt() {
        #expect(NotePanelWidth.shouldSave(new: 270, saved: nil, firstSeen: 270) == false)     // the layout's own width
        #expect(NotePanelWidth.shouldSave(new: 270, saved: nil, firstSeen: 380) == false)     // squeezed below the minimum
        #expect(NotePanelWidth.shouldSave(new: 380, saved: nil, firstSeen: 380) == false)     // not moved
        #expect(NotePanelWidth.shouldSave(new: 450, saved: nil, firstSeen: 380) == true)      // dragged wider
        #expect(NotePanelWidth.shouldSave(new: 320, saved: 450, firstSeen: 450) == true)      // dragged narrower
        #expect(NotePanelWidth.shouldSave(new: 450.5, saved: 450, firstSeen: 380) == false)   // already saved
        #expect(NotePanelWidth.shouldSave(new: 1_300, saved: nil, firstSeen: 380) == false)   // beyond the maximum: not a width we offer
        #expect(NotePanelWidth.shouldSave(new: .nan, saved: nil, firstSeen: 380) == false)
        #expect(NotePanelWidth.shouldSave(new: 450, saved: nil, firstSeen: nil) == false)     // nothing to compare with yet
    }

    /// Decision 0050 point 5: a width saved by an earlier version is dropped once, so everyone starts at the new first width. After that
    /// the width the person drags is kept.
    @Test func aWidthSavedByAnEarlierVersionIsDroppedOnce() {
        let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
        store.set(380.0, forKey: NotePanelWidth.earlierKey)
        #expect(NotePanelWidth.load(from: store) == 640)
        #expect(store.object(forKey: NotePanelWidth.earlierKey) == nil)                    // the old value is gone
        NotePanelWidth.save(900, to: store)
        #expect(NotePanelWidth.load(from: store) == 900)                                  // a new choice is kept
        #expect(NotePanelWidth.key != NotePanelWidth.earlierKey)
    }

    /// Specification 3.5: a narrow window leaves 360 pt for the article, and for the list the width it has when it is shown (400 pt at
    /// first, at least 280 pt), and 80 pt more, also while the list is folded.
    @Test func aNarrowWindowLimitsThePanel() {
        #expect(NotePanelWidth.maximum(windowWidth: 1_240) == 400)                              // the list's room is kept while it is folded
        #expect(NotePanelWidth.maximum(windowWidth: 1_240, listWidth: 280) == 520)
        #expect(NotePanelWidth.maximum(windowWidth: 1_240, listWidth: 100) == 520)             // never less than the list's minimum
        #expect(NotePanelWidth.maximum(windowWidth: 1_240, listWidth: 640) == 300)             // a wide list takes the room (the list gives way to 580)
        #expect(NotePanelWidth.maximum(windowWidth: 3_000) == 1_280)                           // never above the widest we offer
        #expect(NotePanelWidth.maximum(windowWidth: 960) == 300)                               // the smallest window: the panel's own minimum
        #expect(NotePanelWidth.maximum(windowWidth: 700, listWidth: 640) == 300)
        #expect(NotePanelWidth.maximum(windowWidth: .nan) == 1_280)
    }

    /// A window that squeezed the panel must not change the width the person kept (a 1,100 pt note in a 1,240 pt window is shown at 400 pt).
    @Test func aWidthAtTheWindowsLimitIsNotKept() {
        #expect(NotePanelWidth.shouldSave(new: 400, saved: 1_100, firstSeen: 1_100, limit: 400) == false)
        #expect(NotePanelWidth.shouldSave(new: 700, saved: 1_100, firstSeen: 1_100, limit: 400) == true)     // dragged to a width of its own
    }
}
