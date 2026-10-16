import Testing
@testable import ReaderCore

// Specification 3.7: the article's text size.
struct ArticleTextSizeTests {
    @Test func thereAreFiveStepsAndSixteenIsTheStandard() {
        #expect(ArticleTextSize.steps == [14, 16, 18, 20, 22])
        #expect(ArticleTextSize.standard == 16)
        #expect(ArticleTextSize.scale(16) == 1)
    }

    @Test func aValueThatIsNotAStepBecomesTheNearestStep() {
        #expect(ArticleTextSize.step(15.2) == 16)
        #expect(ArticleTextSize.step(14.9) == 14)
        #expect(ArticleTextSize.step(30) == 22)
        #expect(ArticleTextSize.step(0) == 14)
        #expect(ArticleTextSize.step(.nan) == 16)
        #expect(ArticleTextSize.step(.infinity) == 16)
    }

    @Test func theTitleAndTheSourceLinesFollowByTheSameRatio() {
        #expect(ArticleTextSize.scale(22) == 1.375)
        #expect(26 * ArticleTextSize.scale(22) == 35.75)                  // the title
        #expect(11 * ArticleTextSize.scale(14) == 9.625)                  // the source line
    }
}
