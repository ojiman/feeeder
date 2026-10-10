import Foundation

public enum AssistantAvailability: Sendable, Equatable { case available, assetsMissing, unsupported }

/// One plain-text request to the on-device model: fixed instructions, the prompt, and a cap on the output.
public struct TextRequest: Sendable, Equatable {
    public let instructions: String
    public let prompt: String
    public let maximumTokens: Int
    public init(instructions: String, prompt: String, maximumTokens: Int) {
        self.instructions = instructions; self.prompt = prompt; self.maximumTokens = maximumTokens
    }
}

/// The on-device model behind a protocol so tests never touch a real one. Implementations must not use the network and must not
/// request system assets (decision 0009). They run off the main actor. Every throw means "no text"; callers never block reading on it.
public protocol TextGenerator: Sendable {
    /// State of the text-generation model. Never starts a download.
    func generationAvailability() async -> AssistantAvailability
    func generate(_ request: TextRequest) async throws -> String
}
