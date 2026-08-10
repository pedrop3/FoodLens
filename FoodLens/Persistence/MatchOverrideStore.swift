import Foundation
import SwiftData

/// Acesso de leitura/escrita a `MatchOverride`, isolado do resto do
/// `Matcher` — o Matcher só pede "há um override para este texto?", sem
/// saber nada de SwiftData diretamente.
///
/// `@MainActor`: `ModelContext` não é seguro para usar a partir de vários
/// actors ao mesmo tempo; concentrar o acesso na main actor evita ter de
/// pensar em contextos por thread numa app deste tamanho. Alinha com
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` já configurado no projeto.
@MainActor
final class MatchOverrideStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func override(for label: String) -> MatchOverride? {
        let key = Self.normalizedKey(for: label)
        var descriptor = FetchDescriptor<MatchOverride>(
            predicate: #Predicate { $0.normalizedKey == key }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Chamado explicitamente quando o utilizador corrige um alimento na
    /// UI — nunca automaticamente a partir de uma correspondência
    /// INSA/USDA. Só correções confirmadas pelo utilizador contam como
    /// override.
    @discardableResult
    func save(label: String, matchedName: String, kcalPer100g: Double) -> MatchOverride {
        if let existing = override(for: label) {
            existing.matchedName = matchedName
            existing.kcalPer100g = kcalPer100g
            existing.createdAt = .now
            return existing
        }
        let entry = MatchOverride(
            normalizedKey: Self.normalizedKey(for: label),
            matchedName: matchedName,
            kcalPer100g: kcalPer100g
        )
        context.insert(entry)
        return entry
    }

    static func normalizedKey(for label: String) -> String {
        FoodIndex.tokenize(label).joined(separator: "-")
    }
}
