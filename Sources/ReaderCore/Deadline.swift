import Foundation

public struct DeadlineExceeded: Error, Equatable, Sendable {}

/// Runs `operation` and gives up with `DeadlineExceeded` after `seconds`. The caller is released at the deadline
/// even if the operation never checks for cancellation (it is cancelled and left to finish on its own), and a
/// fast operation returns at once. Cancelling the caller cancels the operation and throws `CancellationError`.
public func withDeadline<T: Sendable>(_ seconds: Double, _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
    let race = DeadlineRace<T>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
            race.install(continuation)
            race.track(Task { do { race.finish(.success(try await operation())) } catch { race.finish(.failure(error)) } })
            race.track(Task { try? await Task.sleep(for: .seconds(seconds)); race.finish(.failure(DeadlineExceeded())) })
        }
    } onCancel: {
        race.finish(.failure(CancellationError()))
    }
}

/// First outcome wins; later ones are ignored. Safe to settle before the continuation is installed.
private final class DeadlineRace<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    private var outcome: Result<T, any Error>?
    private var tasks: [Task<Void, Never>] = []

    func install(_ continuation: CheckedContinuation<T, any Error>) {
        lock.lock()
        if let outcome { lock.unlock(); continuation.resume(with: outcome); return }
        self.continuation = continuation
        lock.unlock()
    }

    func track(_ task: Task<Void, Never>) {
        lock.lock()
        if outcome != nil { lock.unlock(); task.cancel(); return }
        tasks.append(task)
        lock.unlock()
    }

    func finish(_ result: Result<T, any Error>) {
        lock.lock()
        guard outcome == nil else { lock.unlock(); return }
        outcome = result
        let waiting = continuation; continuation = nil
        let running = tasks; tasks = []
        lock.unlock()
        running.forEach { $0.cancel() }
        waiting?.resume(with: result)
    }
}
