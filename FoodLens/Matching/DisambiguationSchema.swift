import Foundation

/// Prompt e forma do JSON para a chamada de desambiguação, o mesmo
/// contrato partilhado pelos três providers, tal como
/// `VisionRecognitionSchema` faz para o reconhecimento por imagem.
enum DisambiguationSchema {
    static func prompt(recognized: RecognizedFood, candidates: [FoodMatch]) -> String {
        var lines = [
            "A visão de uma app de calorias identificou o seguinte alimento numa fotografia:",
            "",
            "Nome: \(recognized.label)",
        ]

        if let notes = recognized.notes, !notes.isEmpty {
            lines.append("Detalhe: \(notes)")
        }
        if !recognized.labelAlternatives.isEmpty {
            lines.append("Outras hipóteses consideradas pela visão: \(recognized.labelAlternatives.joined(separator: ", "))")
        }

        lines.append("")
        lines.append("Candidatos de uma tabela oficial de composição nutricional (INSA):")
        lines.append("")
        for (index, match) in candidates.enumerated() {
            lines.append("\(index + 1). \(match.food.name) — \(Int(match.food.kcalPer100g)) kcal/100g")
        }

        lines.append("")
        lines.append("""
        Qual destes candidatos é genuinamente o mesmo alimento? Responde \
        APENAS com JSON, sem texto antes ou depois, exatamente neste \
        formato:

        { "choice": 0 }

        Onde o número é a posição do candidato certo na lista (1 a \(candidates.count)), \
        ou 0 se nenhum corresponder de facto ao mesmo alimento. Prefere 0 a \
        forçar uma correspondência aproximada — só escolhe um número quando \
        tiveres a certeza de que é o mesmo alimento, não só um parecido.
        """)

        return lines.joined(separator: "\n")
    }

    static func parseChoice(from text: String, candidateCount: Int) -> Int? {
        let jsonText = JSONResponseCleaning.stripMarkdownFence(text)
        guard let data = jsonText.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ChoiceDTO.self, from: data) else {
            return nil
        }
        guard decoded.choice >= 1 && decoded.choice <= candidateCount else { return nil }
        return decoded.choice
    }

    private struct ChoiceDTO: Decodable {
        let choice: Int
    }
}
