import Foundation
import Testing

/// Label expectations use English on every Mac. This never writes a persistent or global language preference.
struct EnglishLanguage: SuiteTrait, TestTrait {
    func prepare(for test: Test) async throws { _ = Self.install }
    var isRecursive: Bool { true }
    private static let install: Void = {
        let defaults = UserDefaults.standard
        var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments["AppleLanguages"] = ["en"]
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }()
}
