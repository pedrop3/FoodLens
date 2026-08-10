import SwiftUI

/// Barra fixa no topo do ecrã de resultados — fora da `List`, por isso
/// nunca faz scroll com o resto: o total tem de estar sempre visível,
/// como pedido ("O total fica sticky no topo").
struct MealTotalBar: View {
    let total: Interval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Total da refeição")
                .font(.caption)
                .foregroundStyle(.secondary)
            IntervalBarView(interval: total, scaleMax: max(total.max, 1), tint: .primary)
        }
        .padding()
        .background(.thinMaterial)
    }
}

#Preview {
    MealTotalBar(total: Interval(min: 420, likely: 560, max: 730))
}
