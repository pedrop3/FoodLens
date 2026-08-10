import Foundation


struct OllamaVisionProvider: VisionProvider, MatchDisambiguating {
    var baseURL: URL = URL(string: "http://localhost:11434")!
    var model: String = "llava"
    var session: URLSession = .shared

    func recognize(_ image: Data) async throws -> [RecognizedFood] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = GenerateRequest(
            model: model,
            prompt: VisionRecognitionSchema.prompt,
            images: [image.base64EncodedString()],
            stream: false
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

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return try VisionRecognitionSchema.parseFoods(from: decoded.response)
    }


    func disambiguate(recognized: RecognizedFood, candidates: [FoodMatch]) async throws -> String? {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = GenerateRequest(
            model: model,
            prompt: DisambiguationSchema.prompt(recognized: recognized, candidates: candidates),
            images: [],
            stream: false
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

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        guard let choice = DisambiguationSchema.parseChoice(from: decoded.response, candidateCount: candidates.count) else {
            return nil
        }
        return candidates[choice - 1].food.id
    }
}

private struct GenerateRequest: Encodable {
    let model: String
    let prompt: String
    let images: [String]
    let stream: Bool
}

private struct GenerateResponse: Decodable {
    let response: String
}
