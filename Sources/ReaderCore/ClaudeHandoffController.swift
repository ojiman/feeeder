import Foundation
import Observation

@MainActor public protocol ClaudeLaunching { func open(_ url: URL) async throws }

@Observable @MainActor public final class ClaudeHandoffController {
    public private(set) var launching = false
    public private(set) var opened = false
    public private(set) var error: String?
    public private(set) var file: URL?
    public private(set) var nextExpiry: Date?
    public private(set) var maintenanceError: String?
    public let directory: URL
    @ObservationIgnored private let review: AIPackageReview
    @ObservationIgnored private let launcher: any ClaudeLaunching
    @ObservationIgnored private let now: @MainActor () -> Date
    public init(directory: URL, review: AIPackageReview, launcher: any ClaudeLaunching, now: @escaping @MainActor () -> Date = { .now }) {
        self.directory = directory; self.review = review; self.launcher = launcher; self.now = now
    }
    public func open(package: AIPackage) async {
        guard !launching else { return }
        launching = true; opened = false; error = nil
        defer { launching = false }
        do {
            let current = try review.validated(at: now())
            guard current.id == package.id && current.sha256 == package.sha256 else { throw HandoffError.changed }
            let file = try HandoffFiles.write(current, directory: directory)
            self.file = file
            // A damaged older operation must not prevent this newly reviewed file from opening.
            // Whole-directory reconciliation reports that older cleanup failure independently.
            nextExpiry = min(nextExpiry ?? current.expiresAt, current.expiresAt)
            try HandoffFiles.validate(file: file, expectedHash: current.sha256, at: now(), expiresAt: current.expiresAt)
            let latest = try review.validated(at: now())
            guard latest.id == current.id && latest.sha256 == current.sha256 else { throw HandoffError.changed }
            try await launcher.open(ClaudeLink.make(prompt: ClaudeLink.prompt, file: file))
            opened = true
        } catch { self.error = error.localizedDescription }
    }
    public func resetStatus() { opened = false; error = nil; file = nil }
    public func reconcile(with store: ReaderStore, at: Date) {
        review.reconcile(at: at)
        do {
            let selections = try HandoffFiles.sourceSelections(directory: directory)
            let expiries = try store.availableInputExpiries(selections: selections, at: at)
            try HandoffFiles.reconcile(directory: directory, validInputExpiries: expiries, noteContextIsValid: { noteID, sourceArticleIDs in
                store.note(id: noteID) != nil
                    && Set(sourceArticleIDs).isSubset(of: Set(store.noteArticleIDs(noteID: noteID)))
            }, at: at)
            nextExpiry = try HandoffFiles.nextExpiry(directory: directory)
            if let file, !FileManager.default.fileExists(atPath: file.path) { self.file = nil; opened = false }
            maintenanceError = nil
        } catch {
            nextExpiry = try? HandoffFiles.nextExpiry(directory: directory)
            maintenanceError = error.localizedDescription; opened = false
        }
    }
}
