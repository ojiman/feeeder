import Foundation
import Testing
@testable import ReaderCore

struct RobotsPolicyTests {
    @Test func equivalentUnicodeAndPercentEncodedPathsRespectRestrictions() {
        for (rule, path) in [("/検索", "/%E6%A4%9C%E7%B4%A2/article"),
                             ("/%e6%a4%9c%e7%b4%a2", "/検索/article"),
                             ("/private", "/priv%61te/article"), ("/priv%61te", "/private/article")] {
            #expect(!RobotsPolicy.permits(url: URL(string: "https://example.test" + path)!,
                robotsText: "User-agent: *\nDisallow: " + rule, userAgent: "Feeeder"))
        }
        let text = "User-agent: *\nDisallow: /検索\nAllow: /検索/public\nDisallow: /file-%2a.html$\n"
        #expect(RobotsPolicy.permits(url: URL(string: "https://example.test/検索/public/1")!, robotsText: text, userAgent: "Feeeder"))
        #expect(!RobotsPolicy.permits(url: URL(string: "https://example.test/file-*.html")!, robotsText: text, userAgent: "Feeeder"))
        #expect(RobotsPolicy.permits(url: URL(string: "https://example.test/file-other.html")!, robotsText: text, userAgent: "Feeeder"))
        #expect(!RobotsPolicy.permits(url: URL(string: "https://example.test/anything")!, robotsText: "User-agent: *\nDisallow: /bad%zz", userAgent: "Feeeder"))
    }
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
