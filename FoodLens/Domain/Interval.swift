import Foundation

/// Um valor com incerteza: mínimo, mais provável e máximo.
///
/// Existe para que a incerteza seja propagada por todo o sistema em vez de
/// morrer no primeiro sítio onde alguém pega só no "provável". Peso (g),
/// kcal por item e kcal total são todos `Interval` — nunca `Double` solto.
struct Interval: Hashable, Codable {
    var min: Double
    var likely: Double
    var max: Double

    static let zero = Interval(min: 0, likely: 0, max: 0)

    init(min: Double, likely: Double, max: Double) {
        self.min = Swift.min(min, likely, max)
        self.max = Swift.max(min, likely, max)
        self.likely = Swift.min(Swift.max(likely, self.min), self.max)
    }

    init(_ value: Double) {
        self.init(min: value, likely: value, max: value)
    }
}

extension Interval {
    static func + (lhs: Interval, rhs: Interval) -> Interval {
        Interval(min: lhs.min + rhs.min, likely: lhs.likely + rhs.likely, max: lhs.max + rhs.max)
    }

    /// Escala por um fator sem incerteza própria (ex.: gramas × kcal/g
    /// quando kcal/g vem de uma fonte pontual como o INSA).
    static func * (lhs: Interval, rhs: Double) -> Interval {
        Interval(min: lhs.min * rhs, likely: lhs.likely * rhs, max: lhs.max * rhs)
    }

    static func * (lhs: Double, rhs: Interval) -> Interval {
        rhs * lhs
    }

    /// Multiplicação de dois valores incertos (ex.: gramas × kcal/100g,
    /// quando o próprio kcal/100g também é uma estimativa, caso da IA a
    /// estimar calorias diretamente, sem tabela). Assume os dois
    /// intervalos não-negativos (gramas e kcal nunca são negativos neste
    /// domínio), por isso o mínimo do produto é sempre min×min e o
    /// máximo é sempre max×max ,não é a regra geral de multiplicação de
    /// intervalos com sinal, que teria de considerar as quatro
    /// combinações de extremos.
    static func * (lhs: Interval, rhs: Interval) -> Interval {
        Interval(min: lhs.min * rhs.min, likely: lhs.likely * rhs.likely, max: lhs.max * rhs.max)
    }
}

extension Interval: CustomStringConvertible {
    /// Representação por omissão para debug/logs. A UI não deve usar isto
    /// diretamente — tem as suas próprias regras de arredondamento e locale.
    var description: String {
        "\(Int(min.rounded()))–\(Int(max.rounded())) (≈\(Int(likely.rounded())))"
    }
}
