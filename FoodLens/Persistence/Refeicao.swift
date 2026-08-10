import Foundation
import SwiftData

/// Uma refeição guardada no histórico.
@Model
final class Refeicao {
    var data: Date


    var thumbnailData: Data?

    @Relationship(deleteRule: .cascade, inverse: \Alimento.refeicao)
    var itens: [Alimento] = []

    init(data: Date = .now, thumbnailData: Data? = nil, itens: [Alimento] = []) {
        self.data = data
        self.thumbnailData = thumbnailData
        self.itens = itens
    }

    var totalKcal: Interval {
        itens.reduce(.zero) { $0 + $1.kcalEstimate }
    }
}
