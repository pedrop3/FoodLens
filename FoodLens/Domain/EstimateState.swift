import Foundation


enum EstimateState {
    case idle
    case analyzing
    case results([FoodEntry])
    case failed(EstimateError)
}

enum EstimateError: Error, Equatable {
    case visionFailed(String)
    case noFoodsDetected
    case matchingFailed(String)
    case decodingFailed
}
