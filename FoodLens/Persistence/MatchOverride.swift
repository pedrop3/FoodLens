import Foundation
import SwiftData


@Model
final class MatchOverride {

    @Attribute(.unique) var normalizedKey: String

    var matchedName: String
    var kcalPer100g: Double
    var createdAt: Date

    init(normalizedKey: String, matchedName: String, kcalPer100g: Double, createdAt: Date = .now) {
        self.normalizedKey = normalizedKey
        self.matchedName = matchedName
        self.kcalPer100g = kcalPer100g
        self.createdAt = createdAt
    }
}
