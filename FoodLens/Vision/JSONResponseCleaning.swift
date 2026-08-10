import Foundation


enum JSONResponseCleaning {
    static func stripMarkdownFence(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        trimmed = String(trimmed.drop(while: { $0 != "\n" }).dropFirst())
        if let range = trimmed.range(of: "```", options: .backwards) {
            trimmed = String(trimmed[..<range.lowerBound])
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
