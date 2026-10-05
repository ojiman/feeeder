import Foundation
import Testing
@testable import ReaderCore

struct RobotsPolicyTests {
    @Test func mostSpecificGroupAndLongestRuleWin() {
        let text = "User-agent: *\nDisallow: /\n\nUser-agent: Feeeder\nDisallow: /private\nAllow: /private/public\n"
        #expect(RobotsPolicy.permits(url: URL(string: "https://example.test/private/public/1")!, robotsText: text, userAgent: "Feeeder"))
        #expect(!RobotsPolicy.permits(url: URL(string: "https://example.test/private/1")!, robotsText: text, userAgent: "Feeeder"))
        #expect(RobotsPolicy.permits(url: URL(string: "https://example.test/posts/1")!, robotsText: text, userAgent: "Feeeder"))
    }
    @Test func wildcardsQueryAndAmbiguousRestrictionsAreConservative() {
        let text = "User-agent: *\nDisallow: /*?draft=*\nDisallow: /secret$\nAllow: /secret/public\n"
        #expect(!RobotsPolicy.permits(url: URL(string: "https://example.test/one?draft=yes")!, robotsText: text, userAgent: "Feeeder"))
        #expect(!RobotsPolicy.permits(url: URL(string: "https://example.test/secret")!, robotsText: text, userAgent: "Feeeder"))
        #expect(RobotsPolicy.permits(url: URL(string: "https://example.test/secret/public")!, robotsText: text, userAgent: "Feeeder"))
        #expect(!RobotsPolicy.permits(url: URL(string: "https://example.test/one")!, robotsText: "Disallow: /", userAgent: "Feeeder"))
    }
}
