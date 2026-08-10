import Foundation

struct GeminiVisionProvider: VisionProvider, MatchDisambiguating {
    var model: String = "gemini-2.5-flash"
    var session: URLSession = .shared

    private var endpoint: URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
    }

    func recognize(_ image: Data) async throws -> [RecognizedFood] {
        guard let apiKey = try KeychainStore.get(.geminiAPIKey), !apiKey.isEmpty else {
            throw VisionProviderError.missingAPIKey
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = GenerateContentRequest(
            contents: [
                Content(parts: [
                    .inlineData(mimeType: "image/jpeg", base64Data: image.base64EncodedString()),
                    .text(VisionRecognitionSchema.prompt),
                ]),
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw VisionProviderError.transport(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw VisionProviderError.requestFailed(statusCode: status, body: String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first(where: { $0.text != nil })?.text else {
            throw VisionProviderError.emptyResponse
        }

        return try VisionRecognitionSchema.parseFoods(from: text)
    }

    func disambiguate(recognized: RecognizedFood, candidates: [FoodMatch]) async throws -> String? {
        guard let apiKey = try KeychainStore.get(.geminiAPIKey), !apiKey.isEmpty else {
            throw VisionProviderError.missingAPIKey
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = GenerateContentRequest(
            contents: [
                Content(parts: [
                    .text(DisambiguationSchema.prompt(recognized: recognized, candidates: candidates)),
                ]),
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw VisionProviderError.transport(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw VisionProviderError.requestFailed(statusCode: status, body: String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first(where: { $0.text != nil })?.text,
              let choice = DisambiguationSchema.parseChoice(from: text, candidateCount: candidates.count) else {
            return nil
        }
        return candidates[choice - 1].food.id
    }
}

// MARK: - Request DTOs

private struct GenerateContentRequest: Encodable {
    let contents: [Content]
}

private struct Content: Encodable {
    let parts: [Part]
}

/// Parte de conteúdo da Gemini API. `Encodable` manual pela mesma razão
/// que `ContentBlock` em `AnthropicVisionProvider`: "texto" e "imagem
/// inline" têm formas diferentes.
private enum Part: Encodable {
    case text(String)
    case inlineData(mimeType: String, base64Data: String)

    private enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
    private enum InlineDataKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .inlineData(let mimeType, let base64Data):
            var nested = container.nestedContainer(keyedBy: InlineDataKeys.self, forKey: .inlineData)
            try nested.encode(mimeType, forKey: .mimeType)
            try nested.encode(base64Data, forKey: .data)
        }
    }
}

// MARK: - Response DTOs

private struct GenerateContentResponse: Decodable {
    let candidates: [Candidate]
}

private struct Candidate: Decodable {
    let content: ResponseContent
}

private struct ResponseContent: Decodable {
    let parts: [ResponsePart]
}

private struct ResponsePart: Decodable {
    let text: String?
}
