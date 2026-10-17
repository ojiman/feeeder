import Testing
@testable import UnagiReader

/// Issue #218: the web view stays hidden behind the app's dark surface until the page has painted.
@Suite(EnglishLanguage()) struct OriginalPageRevealTests {
    @Test func theSurfaceAndTheSpinnerShowUntilThePageHasPainted() {
        var reveal = OriginalPageReveal()
        #expect(reveal.showsPlaceholder && !reveal.showsPage)
        reveal.painted()
        #expect(!reveal.showsPlaceholder && reveal.showsPage)
    }

    @Test func aFailedLoadShowsNeitherThePlaceholderNorThePage() {
        var reveal = OriginalPageReveal()
        reveal.failed()
        #expect(!reveal.showsPlaceholder && !reveal.showsPage)                       // the failure view takes the column
    }

    @Test func aPaintAfterAFailureDoesNotBringTheBlankPageBack() {
        var reveal = OriginalPageReveal()
        reveal.failed()
        reveal.painted()
        #expect(!reveal.showsPage)
    }
}
