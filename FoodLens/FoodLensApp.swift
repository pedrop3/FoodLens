import SwiftUI
import SwiftData

@main
struct FoodLensApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Refeicao.self,
            Alimento.self,
            MatchOverride.self,
            LearnedMatch.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()


    let foodIndex = FoodIndex()

    var body: some Scene {
        WindowGroup {
            ContentView(foodIndex: foodIndex)
                .task { await loadFoodIndex() }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Carrega o JSON do INSA para o `FoodIndex`.
    private func loadFoodIndex() async {
        guard let url = Bundle.main.url(forResource: "insa_foods", withExtension: "json") else {
            assertionFailure("insa_foods.json não está no bundle — confirma o target membership.")
            return
        }
        do {
            try await foodIndex.load(from: url)
        } catch {
            assertionFailure("Falha a carregar o índice INSA: \(error)")
        }
    }
}
