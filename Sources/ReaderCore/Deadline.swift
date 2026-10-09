import Foundation

public struct DeadlineExceeded: Error, Equatable, Sendable {}

/// Runs `operation` and gives up with `DeadlineExceeded` after `seconds`. The operation is cancelled when it loses,
/// and cancelling the caller cancels both.
public func withDeadline<T: Sendable>(_ seconds: Double, _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask { try await Task.sleep(for: .seconds(seconds)); throw DeadlineExceeded() }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { throw CancellationError() }
        return first
    }
}
