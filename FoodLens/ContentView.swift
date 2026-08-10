import SwiftUI
import SwiftData

/// Histórico de refeições — o ecrã de arranque da app. "Nova refeição"
struct ContentView: View {
    let foodIndex: FoodIndex

    @Query(sort: \Refeicao.data, order: .reverse) private var refeicoes: [Refeicao]
    @State private var showingAnalysis = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if refeicoes.isEmpty {
                    ContentUnavailableView(
                        "Sem refeições",
                        systemImage: "camera",
                        description: Text("Tira uma foto para começares.")
                    )
                } else {
                    List(refeicoes) { refeicao in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(refeicao.data, format: .dateTime.day().month().year().hour().minute())
                                .font(.headline)
                            Text(refeicao.totalKcal.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("FoodLens")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Definições", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAnalysis = true
                    } label: {
                        Label("Nova refeição", systemImage: "camera")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingAnalysis) {
            AnalysisView(foodIndex: foodIndex)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    ContentView(foodIndex: FoodIndex())
        .modelContainer(for: [Refeicao.self, Alimento.self, MatchOverride.self, LearnedMatch.self], inMemory: true)
}
