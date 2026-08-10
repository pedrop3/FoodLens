import Foundation


struct AnthropicVisionProvider: VisionProvider, MatchDisambiguating {
    var model: String = "claude-sonnet-5"
    var maxTokens: Int = 1024
    var session: URLSession = .shared

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"

    func recognize(_ image: Data) async throws -> [RecognizedFood] {
        guard let apiKey = try KeychainStore.get(.anthropicAPIKey), !apiKey.isEmpty else {
            throw VisionProviderError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = MessagesRequest(
            model: model,
            maxTokens: maxTokens,
            messages: [
                Message(role: "user", content: [
                    .image(mediaType: "image/jpeg", base64Data: image.base64EncodedString()),
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

        guard let http = response as? HTTPURLResponse else {
            throw VisionProviderError.emptyResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw VisionProviderError.requestFailed(
                statusCode: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw VisionProviderError.emptyResponse
        }

        return try VisionRecognitionSchema.parseFoods(from: text)
    }


    func disambiguate(recognized: RecognizedFood, candidates: [FoodMatch]) async throws -> String? {
        guard let apiKey = try KeychainStore.get(.anthropicAPIKey), !apiKey.isEmpty else {
            throw VisionProviderError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = MessagesRequest(
            model: model,
            maxTokens: 256,
            messages: [
                Message(role: "user", content: [
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

        guard let http = response as? HTTPURLResponse else {
            throw VisionProviderError.emptyResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw VisionProviderError.requestFailed(
                statusCode: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
              let choice = DisambiguationSchema.parseChoice(from: text, candidateCount: candidates.count) else {
            return nil
        }
        return candidates[choice - 1].food.id
    }
}

// MARK: - Request DTOs

private struct MessagesRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct Message: Encodable {
    let role: String
    let content: [ContentBlock]
}

/// Bloco de conteúdo da Messages API. `Encodable` manual porque "image" e
/// "text" têm formas diferentes — um enum simples não dá para derivar.
private enum ContentBlock: Encodable {
    case text(String)
    case image(mediaType: String, base64Data: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, source
    }
    private enum SourceKeys: String, CodingKey {
        case type, mediaType = "media_type", data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let mediaType, let base64Data):
            try container.encode("image", forKey: .type)
            var source = container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try source.encode("base64", forKey: .type)
            try source.encode(mediaType, forKey: .mediaType)
            try source.encode(base64Data, forKey: .data)
        }
    }
}

// MARK: - Response DTOs

private struct MessagesResponse: Decodable {
    let content: [ResponseBlock]
}

private struct ResponseBlock: Decodable {
    let type: String
    let text: String?
}
