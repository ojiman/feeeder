import Foundation
import Testing
@testable import ReaderCore

struct NotePanelWidthTests {
    private func defaults() -> (UserDefaults, String) {
        let name = "unagi-reader-test-\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test func aWidthInsideTheRangeIsKeptAndOneOutsideIsClamped() {
        #expect(NotePanelWidth.range == 300...640 && NotePanelWidth.defaultWidth == 380)
        #expect(NotePanelWidth.clamped(300) == 300 && NotePanelWidth.clamped(450.5) == 450.5 && NotePanelWidth.clamped(640) == 640)
        #expect(NotePanelWidth.clamped(299.9) == 300 && NotePanelWidth.clamped(0) == 300 && NotePanelWidth.clamped(-50) == 300)
        #expect(NotePanelWidth.clamped(640.1) == 640 && NotePanelWidth.clamped(10_000) == 640)
    }

    @Test func aMissingOrInvalidValueFallsBackToTheDefault() {
        #expect(NotePanelWidth.clamped(nil) == 380)
        #expect(NotePanelWidth.clamped(.nan) == 380 && NotePanelWidth.clamped(.infinity) == 380 && NotePanelWidth.clamped(-.infinity) == 380)
        let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
        #expect(NotePanelWidth.load(from: store) == 380)                                  // nothing saved
        store.set("wide", forKey: NotePanelWidth.key)
        #expect(NotePanelWidth.load(from: store) == 380)                                  // not a number
        store.set(Double.nan, forKey: NotePanelWidth.key)
        #expect(NotePanelWidth.load(from: store) == 380)
    }

    @Test func aSavedWidthComesBackClampedAfterARestart() {
        let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
        NotePanelWidth.save(520, to: store)
        #expect(NotePanelWidth.load(from: store) == 520)
        NotePanelWidth.save(9_999, to: store)                                             // a corrupt or old value is clamped on the way in
        #expect(NotePanelWidth.load(from: store) == 640)
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
    /// minimum (a 270 pt panel in a 1,240 pt window must not turn the default 380 into 300).
    @Test func aWidthIsKeptOnlyWhenThePersonChoseIt() {
        #expect(NotePanelWidth.shouldSave(new: 270, saved: nil, firstSeen: 270) == false)     // the layout's own width
        #expect(NotePanelWidth.shouldSave(new: 270, saved: nil, firstSeen: 380) == false)     // squeezed below the minimum
        #expect(NotePanelWidth.shouldSave(new: 380, saved: nil, firstSeen: 380) == false)     // not moved
        #expect(NotePanelWidth.shouldSave(new: 450, saved: nil, firstSeen: 380) == true)      // dragged wider
        #expect(NotePanelWidth.shouldSave(new: 320, saved: 450, firstSeen: 450) == true)      // dragged narrower
        #expect(NotePanelWidth.shouldSave(new: 450.5, saved: 450, firstSeen: 380) == false)   // already saved
        #expect(NotePanelWidth.shouldSave(new: 700, saved: nil, firstSeen: 380) == false)     // beyond the maximum: not a width we offer
        #expect(NotePanelWidth.shouldSave(new: .nan, saved: nil, firstSeen: 380) == false)
        #expect(NotePanelWidth.shouldSave(new: 450, saved: nil, firstSeen: nil) == false)     // nothing to compare with yet
    }
}
