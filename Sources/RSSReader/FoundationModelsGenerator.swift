import Foundation
import FoundationModels
import ReaderCore

/// The system's on-device language model, asked for plain text with an output-token cap. Every failure (guardrail,
/// context overflow, unavailable model, cancellation) is just thrown: callers treat any throw as "no proposal".
/// Never starts a model download. Prompts are not logged.
struct FoundationModelsGenerator: TextGenerator {
    func generationAvailability() async -> AssistantAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(let reason): reason == .modelNotReady ? .assetsMissing : .unsupported
        @unknown default: .unsupported
        }
    }

    func generate(_ request: TextRequest) async throws -> String {
        let session = LanguageModelSession(instructions: request.instructions)
        let response = try await session.respond(to: request.prompt, options: GenerationOptions(maximumResponseTokens: request.maximumTokens))
        return response.content
    }
}
