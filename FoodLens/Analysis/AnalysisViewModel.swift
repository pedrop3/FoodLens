import Foundation
import Observation

/// Liga `VisionProvider` e `Matcher` ao `EstimateState` que a UI observa.
/// `EstimateState` continua a ser a única fonte de verdade — não há um
/// `entries` paralelo: quando o utilizador corrige gramas, reconstrói-se
/// um novo `.results([FoodEntry])` a partir do atual, em vez de guardar o
/// array duas vezes.
@Observable
final class AnalysisViewModel {
    private(set) var state: EstimateState = .idle

    private let visionProvider: VisionProvider
    private let matcher: Matcher

    init(visionProvider: VisionProvider, matcher: Matcher) {
        self.visionProvider = visionProvider
        self.matcher = matcher
    }

    func analyze(_ imageData: Data) async {
        state = .analyzing
        do {
            let recognized = try await visionProvider.recognize(imageData)
            guard !recognized.isEmpty else {
                state = .failed(.noFoodsDetected)
                return
            }
            let entries = await matcher.match(recognized)
            state = .results(entries)
        } catch let error as VisionProviderError {
            state = .failed(Self.mapVisionError(error))
        } catch {
            state = .failed(.visionFailed(error.localizedDescription))
        }
    }

    func updateWeight(for entryID: UUID, gramas: Double) {
        guard case .results(var entries) = state else { return }
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].weightGrams = Interval(gramas)
        state = .results(entries)
    }

    func reset() {
        state = .idle
    }

    private static func mapVisionError(_ error: VisionProviderError) -> EstimateError {
        switch error {
        case .missingAPIKey:
            return .visionFailed("Chave da API Anthropic não configurada.")
        case .requestFailed(let statusCode, _):
            return .visionFailed("Pedido falhou (HTTP \(statusCode)).")
        case .emptyResponse, .malformedJSON:
            return .decodingFailed
        case .transport(let underlying):
            return .visionFailed(underlying.localizedDescription)
        }
    }
}
