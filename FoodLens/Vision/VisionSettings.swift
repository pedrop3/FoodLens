import Foundation

enum VisionSettings {
    private enum Keys {
        static let backend = "visionBackend"
        static let ollamaBaseURL = "ollamaBaseURL"
        static let ollamaModel = "ollamaModel"
        static let geminiModel = "geminiModel"
        static let anthropicModel = "anthropicModel"
    }

    static var backend: VisionBackend {
        get {
            UserDefaults.standard.string(forKey: Keys.backend)
                .flatMap(VisionBackend.init(rawValue:)) ?? .anthropic
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.backend) }
    }

    static var ollamaBaseURL: URL {
        get {
            UserDefaults.standard.string(forKey: Keys.ollamaBaseURL).flatMap(URL.init(string:))
                ?? URL(string: "http://localhost:11434")!
        }
        set { UserDefaults.standard.set(newValue.absoluteString, forKey: Keys.ollamaBaseURL) }
    }

    static var ollamaModel: String {
        get { UserDefaults.standard.string(forKey: Keys.ollamaModel) ?? "llava" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.ollamaModel) }
    }

    static var geminiModel: String {
        get { UserDefaults.standard.string(forKey: Keys.geminiModel) ?? "gemini-2.5-flash" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.geminiModel) }
    }

    static var anthropicModel: String {
        get { UserDefaults.standard.string(forKey: Keys.anthropicModel) ?? "claude-sonnet-5" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.anthropicModel) }
    }
}
