import Foundation


enum VisionBackend: String, CaseIterable, Codable {
    case anthropic
    case gemini
    case ollama
    #if DEBUG
    case fixture
    #endif

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .gemini: return "Gemini"
        case .ollama: return "Ollama (local)"
        #if DEBUG
        case .fixture: return "Fixture (dev)"
        #endif
        }
    }
}
