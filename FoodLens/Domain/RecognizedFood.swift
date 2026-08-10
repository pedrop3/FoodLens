import Foundation


struct RecognizedFood: Identifiable, Hashable, Codable {
    let id: UUID
    /// Nome tal como o modelo o descreveu (ex.: "arroz branco cozido").
    /// Texto livre porque o modelo de visão não conhece a tabela INSA/USDA.
    var label: String
    /// Peso estimado em gramas, como intervalo.
    var weightGrams: Interval
    var estimatedKcalPer100g: Interval
    /// Confiança do modelo na identificação do alimento (0...1). Distinta
    /// do `matchScore` em `FoodEntry`, que mede a confiança na
    /// correspondência com a tabela nutricional.
    var confidence: Double
    var notes: String?
    var labelAlternatives: [String]

    init(
        id: UUID = UUID(),
        label: String,
        weightGrams: Interval,
        estimatedKcalPer100g: Interval,
        confidence: Double,
        notes: String? = nil,
        labelAlternatives: [String] = []
    ) {
        self.id = id
        self.label = label
        self.weightGrams = weightGrams
        self.estimatedKcalPer100g = estimatedKcalPer100g
        self.confidence = min(max(confidence, 0), 1)
        self.notes = notes
        self.labelAlternatives = labelAlternatives
    }
}
