import Foundation

/// Orquestra os níveis de prioridade: override guardado → cache aprendida
/// de desambiguações anteriores → índice INSA em memória (direto, se o
/// score for alto o suficiente para confiar sem perguntar; ou confirmado
/// por desambiguação, se o score ficar numa faixa ambígua) → USDA como
/// fallback online → estimativa direta do próprio modelo de visão. Nunca
/// propaga a falha de uma fonte individual para quem chama

struct Matcher {
    var overrideStore: MatchOverrideStore
    var learnedMatchStore: LearnedMatchStore
    var foodIndex: FoodIndex
    var usdaProvider: USDALookupProviding
    var disambiguator: MatchDisambiguating

    private let highConfidenceThreshold = 0.7
    private let lowConfidenceThreshold = 0.15
    private let shortlistSize = 6
    private let disambiguatedMatchScore = 0.85

    func match(_ recognized: RecognizedFood) async -> FoodEntry {
        if let override = await overrideStore.override(for: recognized.label) {
            return FoodEntry(
                recognized: recognized,
                matchedName: override.matchedName,
                kcalPer100g: Interval(override.kcalPer100g),
                source: .override,
                matchScore: 1.0
            )
        }

        if let learnedId = await learnedMatchStore.insaFoodId(for: recognized.label),
           let learnedFood = await foodIndex.food(id: learnedId) {
            return FoodEntry(
                recognized: recognized,
                matchedName: learnedFood.name,
                kcalPer100g: Interval(learnedFood.kcalPer100g),
                source: .insa,
                matchScore: disambiguatedMatchScore
            )
        }

        // Notas ("com molho", "frito") entram na query: são texto livre
        // da visão que muitas vezes carrega o detalhe que decide qual
        // entrada da tabela é a certa, mas que o `label` sozinho omite.
        let query = Self.searchQuery(for: recognized)
        let candidates = await foodIndex.search(query, limit: shortlistSize)

        if let best = candidates.first, best.score >= highConfidenceThreshold {
            return FoodEntry(
                recognized: recognized,
                matchedName: best.food.name,
                kcalPer100g: Interval(best.food.kcalPer100g),
                source: .insa,
                matchScore: best.score
            )
        }

        if let best = candidates.first, best.score >= lowConfidenceThreshold,
           let chosenId = try? await disambiguator.disambiguate(recognized: recognized, candidates: candidates),
           let chosenFood = candidates.first(where: { $0.food.id == chosenId })?.food {
            // `await` pelo mesmo motivo do `overrideStore.override(for:)`
            // acima: o hop para a MainActor de `learnedMatchStore`, não
            // porque `remember` seja `async` em si.
            await learnedMatchStore.remember(label: recognized.label, insaFoodId: chosenFood.id)
            return FoodEntry(
                recognized: recognized,
                matchedName: chosenFood.name,
                kcalPer100g: Interval(chosenFood.kcalPer100g),
                source: .insa,
                matchScore: disambiguatedMatchScore
            )
        }

        // USDA é um extra online opcional: se falhar (sem chave, sem rede,
        // limite atingido) não interrompe o fluxo — só significa que não
        // há candidato USDA desta vez.
        if let usdaBest = try? await usdaProvider.search(query).first {
            return FoodEntry(
                recognized: recognized,
                matchedName: usdaBest.name,
                kcalPer100g: Interval(usdaBest.kcalPer100g),
                source: .usda,
                matchScore: usdaBest.score
            )
        }

        // Último nível antes de desistir: a própria visão já estimou
        // kcal/100g ao identificar o alimento (ver
        // `VisionRecognitionSchema` e `RecognizedFood.estimatedKcalPer100g`)
        // — pior do que uma tabela, mas uma estimativa fundamentada em vez
        // de "sem correspondência". `matchScore` usa a confiança de
        // identificação da própria visão: se o modelo não tinha a certeza
        // do que estava a ver, a estimativa de calorias também merece
        // menos confiança.
        if recognized.estimatedKcalPer100g != .zero {
            return FoodEntry(
                recognized: recognized,
                matchedName: recognized.label,
                kcalPer100g: recognized.estimatedKcalPer100g,
                source: .aiEstimate,
                matchScore: recognized.confidence
            )
        }

        return FoodEntry(
            recognized: recognized,
            matchedName: recognized.label,
            kcalPer100g: .zero,
            source: .none,
            matchScore: 0
        )
    }

    /// Casa vários alimentos em paralelo. Cada um consulta as suas
    /// próprias fontes sem partilhar estado mutável relevante entre
    /// chamadas, por isso não há razão para serializar item a item — o
    /// tempo de análise de uma refeição com 5 alimentos não deve ser 5×
    /// o de um só.
    func match(_ foods: [RecognizedFood]) async -> [FoodEntry] {
        await withTaskGroup(of: (Int, FoodEntry).self) { group in
            for (index, food) in foods.enumerated() {
                group.addTask { (index, await match(food)) }
            }
            var results = [FoodEntry?](repeating: nil, count: foods.count)
            for await (index, entry) in group {
                results[index] = entry
            }
            return results.compactMap { $0 }
        }
    }

    private static func searchQuery(for recognized: RecognizedFood) -> String {
        [recognized.label, recognized.notes]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
