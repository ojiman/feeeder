import Foundation
import Testing
@testable import ReaderCore

struct DeadlineTests {
    @Test func aFastOperationReturnsItsValue() async throws {
        let value = try await withDeadline(5) { 42 }
        #expect(value == 42)
    }

    @Test func aSlowOperationIsCutOffAtTheDeadline() async {
        await #expect(throws: DeadlineExceeded.self) {
            try await withDeadline(0.05) { try await Task.sleep(for: .seconds(30)); return 1 }
        }
    }

    @Test func anOperationsOwnErrorPassesThrough() async {
        struct Boom: Error {}
        await #expect(throws: Boom.self) { try await withDeadline(5) { () async throws -> Int in throw Boom() } }
    }

    @Test func cancellingTheCallerCancelsTheOperation() async throws {
        let task = Task { try await withDeadline(30) { try await Task.sleep(for: .seconds(30)); return 1 } }
        try await Task.sleep(for: .milliseconds(30))
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func aFastOperationReturnsAtOnceNotAtTheDeadline() async throws {
        let start = ContinuousClock.now
        let value = try await withDeadline(5) { 7 }
        #expect(value == 7 && start.duration(to: .now) < .seconds(1))
    }

    @Test func anOperationThatIgnoresCancellationStillReleasesTheCallerAtTheDeadline() async {
        let start = ContinuousClock.now
        await #expect(throws: DeadlineExceeded.self) {
            try await withDeadline(0.1) { () async throws -> Int in
                await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }     // never resumes, never checks cancellation
                return 1
            }
        }
        #expect(start.duration(to: .now) < .seconds(2))
    }
}
