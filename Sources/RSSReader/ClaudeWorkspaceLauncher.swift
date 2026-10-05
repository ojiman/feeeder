import AppKit
import ReaderCore

@MainActor struct ClaudeWorkspaceLauncher: ClaudeLaunching {
    func open(_ url: URL) async throws {
        guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else { throw HandoffError.missingApplication }
        guard NSWorkspace.shared.open(url) else { throw HandoffError.launchFailed }
    }
}
