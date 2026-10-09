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
}
