import Foundation
import SwiftData

/// Cache automática de uma desambiguação anterior: da última vez que a
/// visão descreveu um alimento por este texto, um pedido ao modelo de
/// linguagem escolheu este alimento INSA entre os candidatos ambíguos. Da
/// próxima vez que aparecer o mesmo texto, não é preciso perguntar outra
/// vez.
///
/// Distinto de `MatchOverride` de propósito: `MatchOverride` só existe
/// quando o utilizador corrige manualmente algo na UI (confiança máxima,
/// nunca escrito automaticamente); `LearnedMatch` é escrito pelo próprio
/// `Matcher` sempre que uma desambiguação tem sucesso, sem qualquer ação
/// do utilizador — são dois níveis de confiança diferentes e duas origens
/// diferentes, por isso dois modelos separados em vez de sobrecarregar
/// `MatchOverride` com um campo "foi automático ou manual?".
///
/// Guarda o `insaFoodId`, não o nome/kcal em si: o nome e as calorias são
/// sempre lidos de volta do `FoodIndex` no momento do uso
/// (`FoodIndex.food(id:)`), para nunca ficarem desatualizados se a tabela
/// INSA for substituída por uma versão mais recente do bundle.
@Model
final class LearnedMatch {
    @Attribute(.unique) var normalizedKey: String
    var insaFoodId: String
    var createdAt: Date

    init(normalizedKey: String, insaFoodId: String, createdAt: Date = .now) {
        self.normalizedKey = normalizedKey
        self.insaFoodId = insaFoodId
        self.createdAt = createdAt
    }
}
