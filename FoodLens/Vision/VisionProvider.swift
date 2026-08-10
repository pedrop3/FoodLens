import Foundation

/// Fonte de reconhecimento de alimentos numa fotografia.
protocol VisionProvider {
    func recognize(_ image: Data) async throws -> [RecognizedFood]
}

typealias FoodVisionProvider = VisionProvider & MatchDisambiguating

enum VisionProviderError: Error {
    case missingAPIKey
    case requestFailed(statusCode: Int, body: String)
    case emptyResponse
    case malformedJSON(String)
    case transport(Error)
}
