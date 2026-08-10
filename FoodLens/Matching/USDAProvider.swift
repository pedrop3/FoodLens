import Foundation

/// Contrato do fallback online (nível c do Matcher). Protocolo por razões
/// simétricas ao `VisionProvider`: testar o Matcher sem rede nem chave.
protocol USDALookupProviding {
    func search(_ query: String) async throws -> [NutritionCandidate]
}

enum USDAProviderError: Error {
    case missingAPIKey
    case rateLimited
    case requestFailed(statusCode: Int)
    case transport(Error)
}

actor USDAProvider: USDALookupProviding {
    private let session: URLSession
    private let endpoint = URL(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
    private let energyNutrientNumber = "1008"
    private let resultLimit = 3

    private var requestTimestamps: [Date] = []
    private let maxRequestsPerHour = 1000

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(_ query: String) async throws -> [NutritionCandidate] {
        guard let apiKey = try KeychainStore.get(.usdaAPIKey), !apiKey.isEmpty else {
            throw USDAProviderError.missingAPIKey
        }
        try registerRequest()

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: String(resultLimit)),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw USDAProviderError.transport(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw USDAProviderError.requestFailed(statusCode: status)
        }

        let decoded = try JSONDecoder().decode(SearchResponseDTO.self, from: data)

        // A USDA não devolve um score de correspondência. Aproximamos um a
        // partir do ranking já ordenado por relevância pela própria API —
        // decrescente, e propositadamente mais baixo do que o FoodIndex
        // atribuiria a uma correspondência INSA equivalente: isto é o
        // fallback, a tabela não é curada para a dieta portuguesa.
        return decoded.foods.enumerated().compactMap { index, food -> NutritionCandidate? in
            guard let kcal = food.foodNutrients.first(where: { $0.nutrientNumber == energyNutrientNumber })?.value else {
                return nil
            }
            let rankPenalty = Double(index) * 0.15
            let score = max(0.2, 0.6 - rankPenalty)
            return NutritionCandidate(name: food.description, kcalPer100g: kcal, source: .usda, score: score)
        }
    }

    private func registerRequest() throws {
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        requestTimestamps.removeAll { $0 < hourAgo }
        guard requestTimestamps.count < maxRequestsPerHour else {
            throw USDAProviderError.rateLimited
        }
        requestTimestamps.append(now)
    }
}

private struct SearchResponseDTO: Decodable {
    let foods: [FoodDTO]
}

private struct FoodDTO: Decodable {
    let description: String
    let foodNutrients: [NutrientDTO]
}

private struct NutrientDTO: Decodable {
    let nutrientNumber: String?
    let value: Double?
}
