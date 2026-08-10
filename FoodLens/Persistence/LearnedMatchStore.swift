import Foundation
import SwiftData


@MainActor
final class LearnedMatchStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func insaFoodId(for label: String) -> String? {
        let key = MatchOverrideStore.normalizedKey(for: label)
        var descriptor = FetchDescriptor<LearnedMatch>(
            predicate: #Predicate { $0.normalizedKey == key }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.insaFoodId
    }

    func remember(label: String, insaFoodId: String) {
        let key = MatchOverrideStore.normalizedKey(for: label)
        var descriptor = FetchDescriptor<LearnedMatch>(
            predicate: #Predicate { $0.normalizedKey == key }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.insaFoodId = insaFoodId
            existing.createdAt = .now
        } else {
            context.insert(LearnedMatch(normalizedKey: key, insaFoodId: insaFoodId))
        }
    }
}
