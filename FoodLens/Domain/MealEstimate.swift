import Foundation

struct MealEstimate {
    var items: [FoodEntry]

    var totalKcal: Interval {
        items.reduce(.zero) { $0 + $1.kcalEstimate }
    }
}
