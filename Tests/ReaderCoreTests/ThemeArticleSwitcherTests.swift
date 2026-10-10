import Foundation
import Testing
@testable import ReaderCore

@MainActor struct ThemeArticleSwitcherTests {
    let at = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func anEmptyListHasNoMoves() throws {
        #expect(!ThemeArticleSwitcher.canMove(1, from: nil, in: []) && !ThemeArticleSwitcher.canMove(-1, from: nil, in: []))
    }

    @Test func theEndsAreDisabledAndNothingShownOpensTheFirst() {
        let ids = [UUID(), UUID(), UUID()]
        #expect(!ThemeArticleSwitcher.canMove(-1, from: ids[0], in: ids) && ThemeArticleSwitcher.canMove(1, from: ids[0], in: ids))
        #expect(ThemeArticleSwitcher.canMove(-1, from: ids[1], in: ids) && ThemeArticleSwitcher.canMove(1, from: ids[1], in: ids))
        #expect(ThemeArticleSwitcher.canMove(-1, from: ids[2], in: ids) && !ThemeArticleSwitcher.canMove(1, from: ids[2], in: ids))
        #expect(ThemeArticleSwitcher.canMove(1, from: nil, in: ids) && ThemeArticleSwitcher.canMove(-1, from: UUID(), in: ids))
        #expect(ReaderNavigation.move(nil, by: 1, in: ids) == ids[0])
    }
}
