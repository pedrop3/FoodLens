import SwiftUI
import SwiftData


struct RefeicaoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let refeicao: Refeicao

    @State private var mostrarConfirmacao = false

    var body: some View {
        VStack(spacing: 0) {
            header

            MealTotalBar(total: refeicao.totalKcal)

            List {
                ForEach(refeicao.itens) { alimento in
                    AlimentoRowView(alimento: alimento)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(Text(refeicao.data, format: .dateTime.day().month().year()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    mostrarConfirmacao = true
                } label: {
                    Label("Apagar", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Apagar esta refeição?",
            isPresented: $mostrarConfirmacao,
            titleVisibility: .visible
        ) {
            Button("Apagar", role: .destructive, action: apagarRefeicao)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            if let thumbnail {
                thumbnail
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipped()
            }
            Text(refeicao.data, format: .dateTime.day().month().year().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var thumbnail: Image? {
        guard let data = refeicao.thumbnailData, let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    private func apagarRefeicao() {
        modelContext.delete(refeicao)
        dismiss()
    }
}


private struct AlimentoRowView: View {
    let alimento: Alimento

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(alimento.matchedName)
                .font(.body.weight(.medium))
            Text("\(Int(alimento.weightLikely)) g")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Refeicao.self, Alimento.self, MatchOverride.self, LearnedMatch.self,
        configurations: config
    )

    let refeicao = Refeicao()
    container.mainContext.insert(refeicao)

    return NavigationStack {
        RefeicaoDetailView(refeicao: refeicao)
    }
    .modelContainer(container)
}
