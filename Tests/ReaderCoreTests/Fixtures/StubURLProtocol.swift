import Foundation

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Reply: Sendable {
        var status = 200
        var headers: [String: String] = [:]
        var data = Data()
        var error: URLError.Code?
    }
    private static let lock = NSLock()
    nonisolated(unsafe) private static var replies: [URL: Reply] = [:]
    nonisolated(unsafe) private static var requests: [URL: URLRequest] = [:]
    static func register(_ reply: Reply, at url: URL) {
        lock.withLock { replies[url] = reply }
    }
    static func request(at url: URL) -> URLRequest? { lock.withLock { requests[url] } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let reply = Self.lock.withLock {
            Self.requests[url] = request
            return Self.replies[url]
        }
        guard let reply else { client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable)); return }
        if let error = reply.error { client?.urlProtocol(self, didFailWithError: URLError(error)); return }
        let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // Deliver multiple chunks so the receive-time cap is exercised.
        for start in stride(from: 0, to: reply.data.count, by: 4096) {
            client?.urlProtocol(self, didLoad: reply.data.subdata(in: start..<min(start + 4096, reply.data.count)))
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
