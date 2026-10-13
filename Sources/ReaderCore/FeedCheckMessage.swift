import Foundation

/// One plain sentence for each reason an address could not be added: what happened and, where it helps, what to do.
public enum FeedCheckMessage {
    /// `pastedXML` is true on the Option-key path, where the person supplied the text and the publisher is not to blame.
    /// `plainHTTP` is true when the address was typed with `http://`: the app checked the `https://` form (decision 0040),
    /// so a failure to connect there is the person's feed being on http only, which the app does not support (decision 0053).
    public static func text(for error: any Error, pastedXML: Bool = false, plainHTTP: Bool = false) -> String {
        switch error {
        case FeedImportError.invalidXML where pastedXML: return "貼り付けたXMLに誤りがあり、読めませんでした。"
        case HTTPError.status(let code):
            switch code {
            case 404, 410: return "ページが見つかりません（\(code)）。URLを確認してください。"
            case 401, 403: return "このURLは読めません（\(code)）。ログインが必要かもしれません。"
            case 429, 500...: return "サーバーがエラーを返しました（\(code)）。時間をおいて試してください。"
            default: return "サーバーがエラーを返しました（\(code)）。"
            }
        case HTTPError.tooLarge: return "データが大きすぎます（2MBまで）。"
        case let error as URLError: return plainHTTP && failsOverHTTPS(error.code) ? "HTTPSでは読み込めませんでした。HTTPには対応していません。" : text(for: error.code)
        default: return error.localizedDescription
        }
    }

    /// Causes that say nothing about the scheme (no network, no answer, no such host) and an address with a port, which was never tried over https, keep their own sentence.
    private static func failsOverHTTPS(_ code: URLError.Code) -> Bool {
        switch code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff, .timedOut, .cannotFindHost, .dnsLookupFailed, .cancelled, .appTransportSecurityRequiresSecureConnection: false
        default: true
        }
    }

    private static func text(for code: URLError.Code) -> String {
        switch code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff: "ネットワークに接続できません。"
        case .timedOut: "サーバーから応答がありません。"
        case .cannotFindHost, .dnsLookupFailed: "サーバーが見つかりません。URLを確認してください。"
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot, .clientCertificateRejected, .clientCertificateRequired: "安全な接続ができませんでした。"
        case .appTransportSecurityRequiresSecureConnection: "http:// には接続できません。https:// のURLを入れてください。"
        default: "接続できませんでした。"
        }
    }
}
