import Foundation

/// One plain sentence for each reason an address could not be added: what happened and, where it helps, what to do.
public enum FeedCheckMessage {
    /// `pastedXML` is true on the Option-key path, where the person supplied the text and the publisher is not to blame.
    /// `plainHTTP` is true when the address was typed with `http://`: the app checked the `https://` form (decision 0040),
    /// so a failure to connect there is the person's feed being on http only, which the app does not support (decision 0053).
    public static func text(for error: any Error, pastedXML: Bool = false, plainHTTP: Bool = false) -> String {
        switch error {
        case FeedImportError.invalidXML where pastedXML: return String(localized: "The pasted XML could not be read because it contains errors.", bundle: ReaderLocalization.bundle)
        case HTTPError.status(let code):
            switch code {
            case 404, 410: return String(localized: "Page not found (\(code)). Check the URL.", bundle: ReaderLocalization.bundle)
            case 401, 403: return String(localized: "This URL could not be read (\(code)). You may need to log in.", bundle: ReaderLocalization.bundle)
            case 429, 500...: return String(localized: "The server returned an error (\(code)). Try again later.", bundle: ReaderLocalization.bundle)
            default: return String(localized: "The server returned an error (\(code)).", bundle: ReaderLocalization.bundle)
            }
        case HTTPError.tooLarge: return String(localized: "The data is too large (maximum 2 MB).", bundle: ReaderLocalization.bundle)
        case let error as URLError: return plainHTTP && failsOverHTTPS(error.code) ? String(localized: "Could not load over HTTPS. HTTP is not supported.", bundle: ReaderLocalization.bundle) : text(for: error.code)
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
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff: String(localized: "You are not connected to the network.", bundle: ReaderLocalization.bundle)
        case .timedOut: String(localized: "The server did not respond.", bundle: ReaderLocalization.bundle)
        case .cannotFindHost, .dnsLookupFailed: String(localized: "The server could not be found. Check the URL.", bundle: ReaderLocalization.bundle)
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot, .clientCertificateRejected, .clientCertificateRequired: String(localized: "A secure connection could not be made.", bundle: ReaderLocalization.bundle)
        case .appTransportSecurityRequiresSecureConnection: String(localized: "HTTP connections are not supported. Enter an https:// URL.", bundle: ReaderLocalization.bundle)
        default: String(localized: "Could not connect.", bundle: ReaderLocalization.bundle)
        }
    }
}
