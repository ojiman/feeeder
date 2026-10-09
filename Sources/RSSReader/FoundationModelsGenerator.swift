import Foundation
import FoundationModels
import ReaderCore

protocol TextGenerating: Sendable {
    func availability() async -> AssistantAvailability
    func generate(_ request: SuggestionPrompts.Request) async throws -> String
}

/// The system's on-device language model, asked for plain text with an output-token cap. Every failure (guardrail,
/// context overflow, unavailable model, cancellation) is just thrown: callers treat any throw as "no proposal".
/// Never starts a model download. Prompts are not logged.
struct FoundationModelsGenerator: TextGenerating {
    func availability() async -> AssistantAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(let reason): reason == .modelNotReady ? .assetsMissing : .unsupported
        @unknown default: .unsupported
        }
    }

    func generate(_ request: SuggestionPrompts.Request) async throws -> String {
        let session = LanguageModelSession(instructions: request.instructions)
        let response = try await session.respond(to: request.prompt, options: GenerationOptions(maximumResponseTokens: request.maximumTokens))
        return response.content
    }
}
