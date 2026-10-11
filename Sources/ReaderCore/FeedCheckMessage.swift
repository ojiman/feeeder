import Foundation

/// One plain sentence for each reason an address could not be added: what happened and, where it helps, what to do.
public enum FeedCheckMessage {
    public static func text(for error: any Error) -> String {
        switch error {
        case HTTPError.status(let code):
            switch code {
            case 404, 410: return "ページが見つかりません（\(code)）。URLを確認してください。"
            case 401, 403: return "このURLは読めません（\(code)）。ログインが必要かもしれません。"
            case 429, 500...: return "サーバーがエラーを返しました（\(code)）。時間をおいて試してください。"
            default: return "サーバーがエラーを返しました（\(code)）。"
            }
        case HTTPError.tooLarge: return "データが大きすぎます（2MBまで）。"
        case let error as URLError: return text(for: error.code)
        default: return error.localizedDescription
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
