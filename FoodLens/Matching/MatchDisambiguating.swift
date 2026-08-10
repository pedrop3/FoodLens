import Foundation

protocol MatchDisambiguating {
    func disambiguate(recognized: RecognizedFood, candidates: [FoodMatch]) async throws -> String?
}
