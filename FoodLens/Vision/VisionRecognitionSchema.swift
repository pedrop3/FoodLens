import Foundation

enum VisionRecognitionSchema {
    static let prompt = """
    Analisa esta fotografia de uma refeição. Identifica cada alimento \
    visível, estima o peso em gramas, e estima também as calorias por \
    100 g desse alimento.

    Para a estimativa de calorias, raciocina como um nutricionista faria \
    a olho: para pratos simples (um alimento reconhecível, ex. "arroz \
    cozido"), usa o teu conhecimento nutricional direto. Para pratos \
    compostos ou processados (ex. um doce frito com recheio), pensa nos \
    ingredientes principais prováveis, na proporção de cada um, e no \
    método de confeção (frito, salteado, com molho, etc.) antes de \
    decidires o intervalo — não adivinhes um número sem passar por este \
    raciocínio.

    Quando o alimento pertence a uma categoria com variedades \
    visualmente parecidas mas nutricionalmente diferentes (ex.: espécies \
    de peixe como robalo, dourada, pescada; cortes de carne; tipos de \
    queijo), tenta identificar a variedade exata usando pistas visuais \
    (forma do corpo, pele, cor, se está inteiro ou em filete, com ou sem \
    pele/espinha). Não escolhas a mais comum por defeito — decide pelo \
    que vês na fotografia. Se, mesmo assim, não tiveres confiança \
    suficiente para escolher uma só, indica em "label_alternatives" até \
    2 alternativas plausíveis, da mais para a menos provável.

    Responde APENAS com JSON válido, sem texto antes ou depois, exatamente \
    neste formato:

    {
      "foods": [
        {
          "label": "nome do alimento em português",
          "label_alternatives": [],
          "weight_g": { "min": 0, "likely": 0, "max": 0 },
          "estimated_kcal_per_100g": { "min": 0, "likely": 0, "max": 0 },
          "confidence": 0.0,
          "notes": "detalhe opcional (ex.: com molho, frito)"
        }
      ]
    }

    Regras:
    - "min" e "max" definem o intervalo plausível (de peso ou de \
      calorias); "likely" é a tua melhor estimativa dentro desse \
      intervalo.
    - "estimated_kcal_per_100g" é a tua própria estimativa nutricional, \
      independente de qualquer tabela — vai ser usada como aproximação \
      quando não houver correspondência numa tabela de composição de \
      alimentos, por isso deve refletir sempre a tua melhor estimativa, \
      mesmo com incerteza.
    - "label_alternatives" só deve conter outras variedades genuinamente \
      plausíveis para a mesma peça de comida (ex.: outra espécie de \
      peixe parecida) — não variações de tempero ou apresentação, isso é \
      para "notes". Deixa vazio quando tiveres confiança na \
      identificação; não inventes alternativas só para preencher o campo.
    - "confidence" é a tua confiança na identificação do alimento (0 a 1), \
      não no peso nem nas calorias.
    - Um item por alimento distinto no prato; não agregues alimentos \
      diferentes num só item.
    - Se não conseguires identificar nada, devolve {"foods": []}.
    """


    static func parseFoods(from text: String) throws -> [RecognizedFood] {
        let jsonText = JSONResponseCleaning.stripMarkdownFence(text)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw VisionProviderError.malformedJSON(text)
        }

        let decoded: ResponseDTO
        do {
            decoded = try JSONDecoder().decode(ResponseDTO.self, from: jsonData)
        } catch {
            throw VisionProviderError.malformedJSON(text)
        }

        return decoded.foods.map { dto in
            RecognizedFood(
                label: dto.label,
                weightGrams: Interval(min: dto.weightG.min, likely: dto.weightG.likely, max: dto.weightG.max),
                estimatedKcalPer100g: Interval(
                    min: dto.estimatedKcalPer100g.min,
                    likely: dto.estimatedKcalPer100g.likely,
                    max: dto.estimatedKcalPer100g.max
                ),
                confidence: dto.confidence,
                notes: dto.notes,
                labelAlternatives: dto.labelAlternatives ?? []
            )
        }
    }

    private struct ResponseDTO: Decodable {
        let foods: [FoodDTO]
    }

    private struct FoodDTO: Decodable {
        let label: String
        let weightG: RangeDTO
        let estimatedKcalPer100g: RangeDTO
        let confidence: Double
        let notes: String?
        let labelAlternatives: [String]?

        enum CodingKeys: String, CodingKey {
            case label, confidence, notes
            case weightG = "weight_g"
            case estimatedKcalPer100g = "estimated_kcal_per_100g"
            case labelAlternatives = "label_alternatives"
        }
    }

    private struct RangeDTO: Decodable {
        let min: Double
        let likely: Double
        let max: Double
    }
}
