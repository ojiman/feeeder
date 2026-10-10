import Foundation
@testable import ReaderCore

/// Scripted stand-in for the on-device model. A held call parks until released, so tests can finish requests in any order.
actor FakeGenerator: TextGenerator {
    private var generated: [String] = []
    private var generationFailure: (any Error)?
    private var generationAvailabilityValue = AssistantAvailability.available
    private var holdGeneration = false
    private var parkedGeneration: CheckedContinuation<Void, Never>?
    private(set) var generateCalls: [TextRequest] = []
    private(set) var generationAvailabilityCalls = 0

    func scriptGeneration(_ outputs: [String] = [], failure: (any Error)? = nil, hold: Bool = false, availability: AssistantAvailability = .available) {
        generated = outputs; generationFailure = failure; holdGeneration = hold; generationAvailabilityValue = availability
    }
    var generationParked: Bool { parkedGeneration != nil }
    func releaseGeneration() { parkedGeneration?.resume(); parkedGeneration = nil }

    func generationAvailability() async -> AssistantAvailability { generationAvailabilityCalls += 1; return generationAvailabilityValue }
    func generate(_ request: TextRequest) async throws -> String {
        generateCalls.append(request)
        if holdGeneration { await withCheckedContinuation { parkedGeneration = $0 } }
        if let generationFailure { throw generationFailure }
        return generated.isEmpty ? "" : generated.removeFirst()
    }
}

/// A switch the tests can flip while a request is in flight, without capturing a mutable local in a Sendable closure.
@MainActor final class EnabledSwitch { var on = true }
