import Foundation
import Testing
@testable import ReaderCore

@Suite(.serialized) struct ProductIdentityTests {
    @Test func requestsUseTheProductName() async throws {
        let url = URL(string: "https://example.test/identity")!
        StubURLProtocol.register(.init(data: Data("ok".utf8)), at: url)
        _ = try await HTTPClient(protocolClasses: [StubURLProtocol.self]).fetch(url: url, headers: [:], maximumBytes: 1_024)
        #expect(StubURLProtocol.request(at: url)?.value(forHTTPHeaderField: "User-Agent") == "UnagiReader/1.0")
        #expect(AppIdentity.userAgentToken == "UnagiReader")
    }
    @Test func packageAndFileNamesUseTheProductName() throws {
        #expect(AppIdentity.reviewFileName == "UnagiReader-review.txt")
        #expect(AppIdentity.reviewPartPrefix == "UnagiReader-review-part-")
    }
    @Test func theBundleIdentifierInTheBuildScriptMatchesTheCode() throws {
        let script = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "scripts/build-app.sh")
        let text = try String(contentsOf: script, encoding: .utf8)
        #expect(AppIdentity.bundleIdentifier == "xyz.ojima.UnagiReader")
        #expect(text.contains("<key>CFBundleIdentifier</key><string>\(AppIdentity.bundleIdentifier)</string>"))
    }
}
