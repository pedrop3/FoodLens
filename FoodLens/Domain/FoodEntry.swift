import Foundation

/// Fonte da correspondência nutricional de um `FoodEntry`. Mostrado na
/// interface para o utilizador saber o quanto confiar no número.
enum MatchSource: String, Codable, Hashable {
    /// Correção manual anterior do utilizador — a única fonte tratada
    /// como certa (`matchScore` fixo em 1.0 no `Matcher`).
    case override
    case insa
    case usda
    case aiEstimate
    case none
}

/// Um `RecognizedFood` depois de casado com uma fonte nutricional.
struct FoodEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var recognized: RecognizedFood
    /// Nome tal como consta na fonte nutricional — pode diferir do texto
    /// livre da visão (ex.: visão diz "arroz", INSA tem "Arroz, branco, cozido").
    /// Quando `source == .aiEstimate`, é o próprio `recognized.label`: não
    /// há "nome oficial" nenhum, é a estimativa do modelo sobre o que a
    /// visão identificou.
    var matchedName: String
    /// kcal por 100g. Um `Interval`, não um `Double`: fontes de tabela
    /// (INSA/USDA) dão um valor pontual — chega ao `FoodEntry` como um
    /// intervalo degenerado (`min == likely == max`), construído pelo
    /// `Matcher` — mas `.aiEstimate` é uma estimativa com incerteza a
    /// sério, e fingir um número exato aí seria voltar a mostrar um
    /// "número seco" pela porta do lado.
    var kcalPer100g: Interval
    var source: MatchSource
    /// Confiança do Matcher nesta correspondência (0...1). Independente da
    /// `confidence` de visão em `recognized` — um alimento pode ser
    /// reconhecido com grande confiança pela visão e ainda assim casar mal
    /// com a tabela (ex.: nome ambíguo, vários candidatos parecidos).
    var matchScore: Double
    var weightGrams: Interval

    init(
        id: UUID = UUID(),
        recognized: RecognizedFood,
        matchedName: String,
        kcalPer100g: Interval,
        source: MatchSource,
        matchScore: Double,
        weightGrams: Interval? = nil
    ) {
        self.id = id
        self.recognized = recognized
        self.matchedName = matchedName
        self.kcalPer100g = kcalPer100g
        self.source = source
        self.matchScore = min(max(matchScore, 0), 1)
        self.weightGrams = weightGrams ?? recognized.weightGrams
    }

    /// Intervalo de kcal deste alimento à gramagem atual (`weightGrams`,
    /// não a original da visão — reflete correções do utilizador).
    /// `kcalPer100g` é por 100 g, não por grama — daí o `* 0.01`.
    var kcalEstimate: Interval {
        (weightGrams * kcalPer100g) * 0.01
    }
}
