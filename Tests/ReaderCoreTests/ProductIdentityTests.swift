import Foundation
import Testing
@testable import ReaderCore

@Suite(.serialized) struct ProductIdentityTests {
    @Test func requestsAndRobotsRulesUseTheProductName() async throws {
        let url = URL(string: "https://example.test/identity")!
        StubURLProtocol.register(.init(data: Data("ok".utf8)), at: url)
        _ = try await HTTPClient(protocolClasses: [StubURLProtocol.self]).fetch(url: url, headers: [:], maximumBytes: 1_024)
        #expect(StubURLProtocol.request(at: url)?.value(forHTTPHeaderField: "User-Agent") == "UnagiReader/1.0")
        #expect(AppIdentity.userAgentToken == "UnagiReader")
        let robots = "User-agent: *\nAllow: /\n\nUser-agent: UnagiReader\nDisallow: /private\n"
        #expect(!RobotsPolicy.permits(url: URL(string: "https://example.test/private/1")!, robotsText: robots, userAgent: AppIdentity.userAgentToken))
    }
    @Test func packageAndFileNamesUseTheProductName() throws {
        #expect(AppIdentity.reviewFileName == "UnagiReader-review.txt")
        #expect(AppIdentity.reviewPartPrefix == "UnagiReader-review-part-")
    }
}
