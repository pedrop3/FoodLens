import Foundation


enum VisionProviderFactory {
    static func make(backend: VisionBackend = VisionSettings.backend) -> FoodVisionProvider {
        switch backend {
        case .anthropic:
            return AnthropicVisionProvider(model: VisionSettings.anthropicModel)
        case .gemini:
            return GeminiVisionProvider(model: VisionSettings.geminiModel)
        case .ollama:
            return OllamaVisionProvider(baseURL: VisionSettings.ollamaBaseURL, model: VisionSettings.ollamaModel)
        #if DEBUG
        case .fixture:
            return FixtureVisionProvider()
        #endif
        }
    }
}
