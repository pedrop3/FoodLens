import Foundation


struct FixtureVisionProvider: VisionProvider, MatchDisambiguating {
    var results: [RecognizedFood]
    /// Atraso artificial opcional, para a UI de `EstimateState.analyzing`
    /// ser visível/testável em vez de passar num instante.
    var delay: Duration = .zero

    init(results: [RecognizedFood] = FixtureVisionProvider.sampleMeal, delay: Duration = .zero) {
        self.results = results
        self.delay = delay
    }

    func recognize(_ image: Data) async throws -> [RecognizedFood] {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        return results
    }

   
    func disambiguate(recognized: RecognizedFood, candidates: [FoodMatch]) async throws -> String? {
        candidates.first?.food.id
    }

 
    static let sampleMeal: [RecognizedFood] = [
        RecognizedFood(
            label: "arroz branco cozido",
            weightGrams: Interval(min: 120, likely: 150, max: 190),
            estimatedKcalPer100g: Interval(min: 120, likely: 130, max: 145),
            confidence: 0.82
        ),
        RecognizedFood(
            label: "peito de frango grelhado",
            weightGrams: Interval(min: 100, likely: 130, max: 160),
            estimatedKcalPer100g: Interval(min: 150, likely: 165, max: 185),
            confidence: 0.88,
            notes: "grelhado, sem pele aparente"
        ),
        RecognizedFood(
            label: "brócolos cozidos",
            weightGrams: Interval(min: 60, likely: 90, max: 120),
            estimatedKcalPer100g: Interval(min: 28, likely: 35, max: 45),
            confidence: 0.7
        ),
    ]
}
