import SwiftUI
import SwiftData

/// Ecrã principal: fotografar → analisar → rever/corrigir → guardar.
/// Uma coluna, phone-first — sem sidebars nem split view.
struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let foodIndex: FoodIndex

    @State private var viewModel: AnalysisViewModel?
    @State private var capturedImageData: Data?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel?.state ?? .idle {
                case .idle:
                    idleView
                case .analyzing:
                    analyzingView
                case .results(let entries):
                    resultsView(entries)
                case .failed(let error):
                    failedView(error)
                }
            }
            .navigationTitle("Nova refeição")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .onAppear(perform: setupViewModelIfNeeded)
    }

    private func setupViewModelIfNeeded() {
        guard viewModel == nil else { return }
        // O mesmo `provider` serve para reconhecer a foto e para
        // desambiguar candidatos INSA por texto — ver `FoodVisionProvider`
        // em `VisionProvider.swift`: é o mesmo backend configurado, só
        // muda o tipo de chamada.
        let provider = VisionProviderFactory.make()
        let overrideStore = MatchOverrideStore(context: modelContext)
        let learnedMatchStore = LearnedMatchStore(context: modelContext)
        let matcher = Matcher(
            overrideStore: overrideStore,
            learnedMatchStore: learnedMatchStore,
            foodIndex: foodIndex,
            usdaProvider: USDAProvider(),
            disambiguator: provider
        )
        viewModel = AnalysisViewModel(visionProvider: provider, matcher: matcher)
    }

    private func handleNewImage(_ data: Data) {
        capturedImageData = data
        Task { await viewModel?.analyze(data) }
    }

    // MARK: - Estados

    private var idleView: some View {
        ContentUnavailableView {
            Label("Fotografa a refeição", systemImage: "camera")
        } description: {
            Text("A estimativa de calorias tem um erro típico de 20–40% — vê sempre como intervalo, não como número exato.")
        } actions: {
            PhotoSourceMenu(title: "Adicionar foto", onImageData: handleNewImage)
                .buttonStyle(.borderedProminent)
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("A identificar os alimentos…")
                .foregroundStyle(.secondary)
        }
    }

    private func resultsView(_ entries: [FoodEntry]) -> some View {
        let total = entries.reduce(Interval.zero) { $0 + $1.kcalEstimate }
        let scaleMax = max(entries.map { $0.kcalEstimate.max }.max() ?? 1, 1)

        return VStack(spacing: 0) {
            MealTotalBar(total: total)

            List {
                ForEach(entries) { entry in
                    FoodRowView(entry: entry, scaleMax: scaleMax) { newGrams in
                        viewModel?.updateWeight(for: entry.id, gramas: newGrams)
                    }
                }
            }
            .listStyle(.plain)

            saveBar(entries: entries)
        }
    }

    private func failedView(_ error: EstimateError) -> some View {
        ContentUnavailableView {
            Label("Não foi possível analisar", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message(for: error))
        } actions: {
            PhotoSourceMenu(title: "Tentar de novo", onImageData: handleNewImage)
        }
    }

    private func saveBar(entries: [FoodEntry]) -> some View {
        HStack {
            PhotoSourceMenu(title: "Nova foto", onImageData: handleNewImage)
            Spacer()
            Button("Guardar") { save(entries: entries) }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.thinMaterial)
    }

    private func save(entries: [FoodEntry]) {
        let thumbnail = capturedImageData.flatMap { ImageThumbnailer.makeThumbnail(from: $0) }
        let refeicao = Refeicao(thumbnailData: thumbnail)
        for entry in entries {
            let alimento = Alimento(from: entry)
            alimento.refeicao = refeicao
            refeicao.itens.append(alimento)
        }
        modelContext.insert(refeicao)
        dismiss()
    }

    private func message(for error: EstimateError) -> String {
        switch error {
        case .visionFailed(let reason): return reason
        case .noFoodsDetected: return "Não foram identificados alimentos na fotografia."
        case .matchingFailed(let reason): return reason
        case .decodingFailed: return "A resposta da análise veio num formato inesperado."
        }
    }
}

#Preview {
    AnalysisView(foodIndex: FoodIndex())
        .modelContainer(for: [Refeicao.self, Alimento.self, MatchOverride.self, LearnedMatch.self], inMemory: true)
}
