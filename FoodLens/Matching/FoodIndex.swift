import Foundation

/// Um alimento tal como consta na Tabela de Composição de Alimentos do
/// INSA. Representa o JSON convertido incluído no bundle, não um modelo
/// SwiftData, porque os dados são fixos e read-only.
struct INSAFood: Codable, Hashable {
    let id: String
    let name: String
    let kcalPer100g: Double
}

struct FoodMatch: Hashable {
    let food: INSAFood
    let score: Double
}

/// Índice invertido do INSA (1376 alimentos, v7.1), construído uma vez em
/// memória a partir do JSON no bundle.
///
/// É um `actor`, não uma classe ou struct, por duas razões: a construção
/// do índice acontece numa task em background no arranque da app (não deve
/// bloquear a UI), e a procura pode ser chamada a partir de vários sítios
/// (ecrã de resultados, re-matching manual) ao mesmo tempo. Não isolar
/// isto num actor obrigaria a locks manuais à volta de `foods` e
/// `invertedIndex` para o mesmo efeito.

actor FoodIndex {
    private var foods: [String: INSAFood] = [:]
    private var invertedIndex: [String: Set<String>] = [:]

    private var tokenWeights: [String: Double] = [:]
    private var docNorms: [String: Double] = [:]

    private var normalizedNames: [String: String] = [:]

    private(set) var isLoaded = false

    private static let stopWords: Set<String> = [
        "de", "da", "do", "das", "dos", "com", "sem", "em",
        "a", "o", "e", "para", "num", "numa", "ao", "à"
    ]

    init() {}

    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let list = try JSONDecoder().decode([INSAFood].self, from: data)
        index(list)
    }

    /// Constrói o índice a partir de uma lista já em memória, usado por
    /// `load(from:)`, mas também diretamente em testes com fixtures, sem
    /// precisar de um ficheiro no disco.
    func index(_ list: [INSAFood]) {
        foods.removeAll(keepingCapacity: true)
        invertedIndex.removeAll(keepingCapacity: true)
        normalizedNames.removeAll(keepingCapacity: true)
        docNorms.removeAll(keepingCapacity: true)

        var tokensById: [String: [String]] = [:]
        for food in list {
            foods[food.id] = food
            normalizedNames[food.id] = Self.normalize(food.name)
            let tokens = Self.tokenize(food.name)
            tokensById[food.id] = tokens
            for token in tokens {
                invertedIndex[token, default: []].insert(food.id)
            }
        }

        let totalFoods = Double(list.count)
        tokenWeights = invertedIndex.mapValues { ids in
            log((totalFoods + 1) / (Double(ids.count) + 1)) + 1
        }

        docNorms = tokensById.mapValues { tokens in
            Self.norm(of: Set(tokens), weights: tokenWeights)
        }

        isLoaded = true
    }

    /// Procura fuzzy por tokens, com score de similaridade de cosseno
    /// (não soma bruta de pesos): normaliza a query da mesma forma que o
    /// índice, acumula o produto interno com cada candidato (tokens que
    /// bateram exatamente, ou por prefixo com peso reduzido) e divide
    /// pela norma de ambos os lados. Um candidato cujo nome contenha a
    /// query tal e qual (não só os tokens espalhados) recebe um pequeno
    /// bónus — desempata a favor da correspondência mais direta.
    ///
    /// Não é um matching semântico nem tolerante a erros ortográficos —
    /// é deliberadamente simples (tokens + prefixo) porque o texto de
    /// entrada vem de um modelo de visão razoavelmente consistente, não
    /// de escrita livre do utilizador com erros de digitação.
    func search(_ query: String, limit: Int = 5) -> [FoodMatch] {
        let queryTokens = Set(Self.tokenize(query))
        guard !queryTokens.isEmpty else { return [] }

        let queryNorm = Self.norm(of: queryTokens, weights: tokenWeights)
        guard queryNorm > 0 else { return [] }

        var dotById: [String: Double] = [:]
        for token in queryTokens {
            let weight = tokenWeights[token] ?? 1
            for id in invertedIndex[token] ?? [] {
                dotById[id, default: 0] += weight * weight
            }
            // Correspondências só por prefixo (plural/singular sem
            // stemmer completo, ex. "batatas" ↔ "batata") pesam menos do
            // que uma correspondência exata do mesmo token.
            for id in fuzzyOnlyIds(for: token) {
                dotById[id, default: 0] += weight * weight * 0.7
            }
        }

        let normalizedQuery = Self.normalize(query)

        return dotById
            .compactMap { id, dot -> FoodMatch? in
                guard let food = foods[id], let docNorm = docNorms[id], docNorm > 0 else { return nil }
                var score = dot / (queryNorm * docNorm)
                if let name = normalizedNames[id], !normalizedQuery.isEmpty, name.contains(normalizedQuery) {
                    score += 0.15
                }
                return FoodMatch(food: food, score: min(score, 1.0))
            }
            .sorted(by: Self.isOrderedBefore)
            .prefix(limit)
            .map { $0 }
    }

    /// Alimento por `id`, sem procura fuzzy — usado pela `LearnedMatchStore`
    /// para resolver um `id` guardado em cache numa desambiguação anterior
    /// de volta para o nome/kcal atuais da tabela, em vez de congelar esses
    /// valores no momento em que a cache foi criada.
    func food(id: String) -> INSAFood? {
        foods[id]
    }

    /// Desempate determinístico. Score primeiro; empatados, o nome mais
    /// curto ganha (mais provável ser a correspondência direta do que um
    /// prato composto que também contém os mesmos tokens); ainda
    /// empatados, o `id` decide. Sem isto, resultados empatados ficariam à
    /// mercê da ordem de iteração de um `Dictionary` — não garantida, e
    /// variável entre execuções da app.
    private static func isOrderedBefore(_ lhs: FoodMatch, _ rhs: FoodMatch) -> Bool {
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        if lhs.food.name.count != rhs.food.name.count { return lhs.food.name.count < rhs.food.name.count }
        return lhs.food.id < rhs.food.id
    }

    /// IDs cujo nome contém um token que bate por prefixo com `token` (em
    /// qualquer direção) mas não é o próprio `token` — essas entradas
    /// exatas já ficam cobertas por `invertedIndex[token]` em `search`.
    ///
    /// Restrito a tokens com 4+ caracteres: abaixo disso o prefixo deixa
    /// de ser discriminativo (ex.: "ovo" seria prefixo de "ovos", mas
    /// também de nomes sem relação nenhuma) e só acrescentaria ruído.
    private func fuzzyOnlyIds(for token: String) -> Set<String> {
        guard token.count >= 4 else { return [] }
        var result: Set<String> = []
        for (indexedToken, ids) in invertedIndex
        where indexedToken != token && (indexedToken.hasPrefix(token) || token.hasPrefix(indexedToken)) {
            result.formUnion(ids)
        }
        return result
    }

    /// Raiz da soma dos quadrados dos pesos de um conjunto de tokens —
    /// a magnitude do "vetor" desse conjunto, para a similaridade de
    /// cosseno em `search`.
    private static func norm(of tokens: Set<String>, weights: [String: Double]) -> Double {
        tokens.reduce(0.0) { partial, token in
            let weight = weights[token] ?? 1
            return partial + weight * weight
        }.squareRoot()
    }

    /// Minúsculas, sem acentos — a forma partilhada por `tokenize` (para
    /// indexação/procura por token) e pelo bónus de frase em `search`
    /// (que compara strings inteiras, não tokens).
    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_PT"))
            .lowercased()
    }

    /// Normaliza e divide em tokens alfanuméricos, sem stop words nem
    /// tokens vazios.
    static func tokenize(_ text: String) -> [String] {
        normalize(text)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }
}
