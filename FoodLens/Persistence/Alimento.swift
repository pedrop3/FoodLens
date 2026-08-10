import Foundation
import SwiftData


@Model
final class Alimento {
    var recognizedLabel: String
    var recognizedNotes: String?
    var visionConfidence: Double

    var matchedName: String
    var sourceRawValue: String
    var matchScore: Double

    var weightMin: Double
    var weightLikely: Double
    var weightMax: Double

    var kcalPer100gMin: Double
    var kcalPer100gLikely: Double
    var kcalPer100gMax: Double

    var refeicao: Refeicao?

    init(from entry: FoodEntry) {
        self.recognizedLabel = entry.recognized.label
        self.recognizedNotes = entry.recognized.notes
        self.visionConfidence = entry.recognized.confidence
        self.matchedName = entry.matchedName
        self.sourceRawValue = entry.source.rawValue
        self.matchScore = entry.matchScore
        self.weightMin = entry.weightGrams.min
        self.weightLikely = entry.weightGrams.likely
        self.weightMax = entry.weightGrams.max
        self.kcalPer100gMin = entry.kcalPer100g.min
        self.kcalPer100gLikely = entry.kcalPer100g.likely
        self.kcalPer100gMax = entry.kcalPer100g.max
    }

    var asFoodEntry: FoodEntry {
        let weight = Interval(min: weightMin, likely: weightLikely, max: weightMax)
        let kcalPer100g = Interval(min: kcalPer100gMin, likely: kcalPer100gLikely, max: kcalPer100gMax)
        return FoodEntry(
            recognized: RecognizedFood(
                label: recognizedLabel,
                weightGrams: weight,
                estimatedKcalPer100g: kcalPer100g,
                confidence: visionConfidence,
                notes: recognizedNotes
            ),
            matchedName: matchedName,
            kcalPer100g: kcalPer100g,
            source: MatchSource(rawValue: sourceRawValue) ?? .none,
            matchScore: matchScore,
            weightGrams: weight
        )
    }

    /// `kcalPer100gX` é por 100 g
    var kcalEstimate: Interval {
        let weight = Interval(min: weightMin, likely: weightLikely, max: weightMax)
        let kcalPer100g = Interval(min: kcalPer100gMin, likely: kcalPer100gLikely, max: kcalPer100gMax)
        return (weight * kcalPer100g) * 0.01
    }
}
