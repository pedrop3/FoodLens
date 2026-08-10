import SwiftUI


struct IntervalBarView: View {
    let interval: Interval
    let scaleMax: Double
    var tint: Color = .accentColor

    private var minFraction: Double { scaleMax > 0 ? interval.min / scaleMax : 0 }
    private var maxFraction: Double { scaleMax > 0 ? interval.max / scaleMax : 0 }
    private var likelyFraction: Double { scaleMax > 0 ? interval.likely / scaleMax : 0 }
    private var isExact: Bool { interval.max - interval.min < 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline.monospacedDigit())

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)

                    Capsule()
                        .fill(tint.opacity(0.35))
                        .frame(width: max(3, width * (maxFraction - minFraction)))
                        .offset(x: width * minFraction)

                    Rectangle()
                        .fill(tint)
                        .frame(width: 2)
                        .offset(x: max(0, width * likelyFraction - 1))
                }
            }
            .frame(height: 10)
        }
    }

    private var label: String {
        if isExact {
            return "\(Int(interval.likely.rounded())) kcal"
        }
        return "\(Int(interval.min.rounded()))–\(Int(interval.max.rounded())) kcal (≈\(Int(interval.likely.rounded())))"
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        IntervalBarView(interval: Interval(min: 180, likely: 230, max: 310), scaleMax: 400)
        IntervalBarView(interval: Interval(223), scaleMax: 400, tint: .green)
    }
    .padding()
}
