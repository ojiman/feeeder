import Foundation
import Testing
@testable import ReaderCore

/// Decisions 0046 and 0049: the fold of the left panel and the slide of the page are one move.
struct SidebarFoldTests {
    @Test func oneMoveOfAboutAThirdOfASecond() {
        #expect(SidebarFold.motionDuration == 0.3)
    }
}
