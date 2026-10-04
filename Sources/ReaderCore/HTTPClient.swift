import Foundation

public struct HTTPResponse: Sendable {
    public let data: Data
    public let finalURL: URL
    public let statusCode: Int
    public let headers: [String: String]
}

public enum HTTPError: LocalizedError {
    case invalidURL, redirect, tooLarge, invalidResponse, status(Int)
    public var errorDescription: String? {
        switch self {
        case .invalidURL: "HTTP(S)のURLを指定してください。認証情報付きURLは使用できません。"
        case .redirect: "この転送先には接続できませんでした。"
        case .tooLarge: "取得するデータが上限を超えました。"
        case .invalidResponse: "サーバーの応答を確認できませんでした。"
        case .status(let code): "サーバーがエラーを返しました（\(code)）。保存済みの記事は引き続き読めます。"
        }
    }
}

public protocol HTTPFetching: Sendable {
    func fetch(url: URL, headers: [String: String], maximumBytes: Int) async throws -> HTTPResponse
}

// Immutable configuration; each request owns its session and serial delegate.
public struct HTTPClient: HTTPFetching, @unchecked Sendable {
    private let protocolClasses: [AnyClass]?
    public init(protocolClasses: [AnyClass]? = nil) { self.protocolClasses = protocolClasses }
    public static func validateRedirect(from: URL, to: URL) throws {
        guard ArticleURL.validated(to.absoluteString) != nil,
              !(from.scheme?.lowercased() == "https" && to.scheme?.lowercased() == "http") else { throw HTTPError.redirect }
    }
    public func fetch(url: URL, headers: [String: String] = [:], maximumBytes: Int) async throws -> HTTPResponse {
        guard let url = ArticleURL.validated(url.absoluteString), maximumBytes > 0 else { throw HTTPError.invalidURL }
        let receiver = HTTPReceiver(maximumBytes: maximumBytes)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let configuration = URLSessionConfiguration.ephemeral
                configuration.httpCookieStorage = nil
                configuration.httpShouldSetCookies = false
                configuration.urlCredentialStorage = nil
                configuration.urlCache = nil
                configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
                configuration.timeoutIntervalForRequest = 20
                configuration.timeoutIntervalForResource = 20
                if let protocolClasses { configuration.protocolClasses = protocolClasses }
                var request = URLRequest(url: url)
                request.setValue("Feeeder/1.0", forHTTPHeaderField: "User-Agent")
                for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
                receiver.start(configuration: configuration, request: request, continuation: continuation)
            }
        } onCancel: { receiver.cancel() }
    }
}

private final class HTTPReceiver: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let maximumBytes: Int
    private var session: URLSession?
    private var continuation: CheckedContinuation<HTTPResponse, any Error>?
    private var cancelled = false
    // Accessed only on URLSession's serial delegate queue.
    private var data = Data()
    private var response: HTTPURLResponse?
    private var redirects = 0
    init(maximumBytes: Int) { self.maximumBytes = maximumBytes }
    func start(configuration: URLSessionConfiguration, request: URLRequest, continuation: CheckedContinuation<HTTPResponse, any Error>) {
        lock.lock()
        if cancelled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
        self.continuation = continuation
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.dataTask(with: request)
        lock.unlock()
        task.resume()
    }
    func cancel() { lock.withLock { cancelled = true }; finish(.failure(CancellationError())) }
    private func finish(_ result: Result<HTTPResponse, any Error>) {
        let state = lock.withLock {
            let state = (continuation, session)
            continuation = nil; session = nil
            return state
        }
        state.0?.resume(with: result)
        state.1?.invalidateAndCancel()
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse, let url = http.url, ArticleURL.validated(url.absoluteString) != nil else {
            completionHandler(.cancel); finish(.failure(HTTPError.invalidResponse)); return
        }
        guard response.expectedContentLength <= Int64(maximumBytes) else {
            completionHandler(.cancel); finish(.failure(HTTPError.tooLarge)); return
        }
        self.response = http; completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard self.data.count <= maximumBytes - data.count else { finish(.failure(HTTPError.tooLarge)); return }
        self.data.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error { finish(.failure(error)); return }
        guard let response, let url = response.url else { finish(.failure(HTTPError.invalidResponse)); return }
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields { headers[String(describing: key).lowercased()] = String(describing: value) }
        finish(.success(HTTPResponse(data: data, finalURL: url, statusCode: response.statusCode, headers: headers)))
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        do {
            redirects += 1
            guard redirects <= 5, let from = response.url, let to = request.url else { throw HTTPError.redirect }
            try HTTPClient.validateRedirect(from: from, to: to)
            var safe = request
            safe.setValue(nil, forHTTPHeaderField: "Cookie")
            safe.setValue(nil, forHTTPHeaderField: "Authorization")
            completionHandler(safe)
        } catch { completionHandler(nil); finish(.failure(error)) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else { completionHandler(.cancelAuthenticationChallenge, nil) }
    }
}
