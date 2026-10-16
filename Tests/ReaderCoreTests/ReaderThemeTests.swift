import Testing
@testable import ReaderCore

// Specification 3.7: the theme and Sepia's contrast.
struct ReaderThemeTests {
    @Test func storedValuesMapToThemesAndUnknownOnesFollowTheSystem() {
        #expect(ReaderTheme(stored: "sepia") == .sepia)
        #expect(ReaderTheme(stored: "dark") == .dark)
        #expect(ReaderTheme(stored: nil) == .system)
        #expect(ReaderTheme(stored: "midnight") == .system)
        #expect(ReaderTheme.allCases.map(\.rawValue) == ["system", "light", "dark", "sepia"])
    }

    @Test func sepiaIsDrawnLightAndTheSystemIsFollowed() {
        #expect(ReaderTheme.sepia.isDark == false)
        #expect(ReaderTheme.light.isDark == false)
        #expect(ReaderTheme.dark.isDark == true)
        #expect(ReaderTheme.system.isDark == nil)
    }

    private let black = SepiaPalette.RGB(red: 0, green: 0, blue: 0)

    @Test func bodyTextOnThePaperHasAtLeastFourAndAHalfToOne() {
        // The light look's text is black at 85% (labelColor); on the paper and on the sidebar.
        let text = SepiaPalette.blend(black, alpha: 0.85, on: SepiaPalette.paper)
        #expect(SepiaPalette.contrast(text, SepiaPalette.paper) >= 4.5)
        let sidebarText = SepiaPalette.blend(black, alpha: 0.85, on: SepiaPalette.sidebar)
        #expect(SepiaPalette.contrast(sidebarText, SepiaPalette.sidebar) >= 4.5)
    }

    @Test func secondaryTextOnThePaperIsAsReadableAsOnWhite() {
        // Read rows and the source line use secondaryLabelColor, black at about 50%: no worse than 10% below its contrast on white.
        let white = SepiaPalette.RGB(red: 255, green: 255, blue: 255)
        let onWhite = SepiaPalette.contrast(SepiaPalette.blend(black, alpha: 0.5, on: white), white)
        let onPaper = SepiaPalette.contrast(SepiaPalette.blend(black, alpha: 0.5, on: SepiaPalette.paper), SepiaPalette.paper)
        #expect(onPaper >= onWhite * 0.9)
    }

    @Test func theSidebarIsALittleDarkerThanThePaper() {
        let ratio = SepiaPalette.contrast(SepiaPalette.paper, SepiaPalette.sidebar)
        #expect(ratio > 1.03 && ratio < 1.2)
    }
}
