import SwiftUI


struct FoodRowView: View {
    let entry: FoodEntry
    let scaleMax: Double
    var onWeightChange: (Double) -> Void

    @State private var grams: Double

    init(entry: FoodEntry, scaleMax: Double, onWeightChange: @escaping (Double) -> Void) {
        self.entry = entry
        self.scaleMax = scaleMax
        self.onWeightChange = onWeightChange
        _grams = State(initialValue: entry.weightGrams.likely)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.matchedName)
                    .font(.body.weight(.medium))
                Spacer()
                SourceBadge(source: entry.source, score: entry.matchScore)
            }

            IntervalBarView(interval: entry.kcalEstimate, scaleMax: scaleMax, tint: tint(for: entry.source))

            Stepper(value: $grams, in: 0...2000, step: 5) {
                Text("\(Int(grams)) g")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .onChange(of: grams) { _, newValue in
                onWeightChange(newValue)
            }
        }
        .padding(.vertical, 6)
    }

    private func tint(for source: MatchSource) -> Color {
        switch source {
        case .override: return .green
        case .insa: return .accentColor
        case .usda: return .orange
        case .aiEstimate: return .purple
        case .none: return .red
        }
    }
}


private struct SourceBadge: View {
    let source: MatchSource
    let score: Double

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch source {
        case .override: return "corrigido"
        case .insa: return "INSA \(percent)"
        case .usda: return "USDA \(percent)"
        case .aiEstimate: return "estimativa IA \(percent)"
        case .none: return "sem correspondência"
        }
    }

    private var percent: String { "\(Int(score * 100))%" }

    private var color: Color {
        switch source {
        case .override: return .green
        case .insa: return .accentColor
        case .usda: return .orange
        case .aiEstimate: return .purple
        case .none: return .red
        }
    }
}
