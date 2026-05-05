import Foundation

struct TextPolisher {
    func polish(_ rawText: String) -> String {
        let withoutSpecialTokens = rawText.replacingOccurrences(
            of: #"<\|[^|]+\|>"#,
            with: "",
            options: .regularExpression
        )
        let normalized = withoutSpecialTokens
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return collapseAdjacentRepeatedPhrases(in: normalized)
    }

    private func collapseAdjacentRepeatedPhrases(in text: String) -> String {
        var words = text.split(separator: " ").map(String.init)
        guard words.count > 1 else { return text }

        var index = 0
        while index < words.count {
            var removed = false
            let maxLength = min(8, (words.count - index) / 2)
            if maxLength > 0 {
                for length in stride(from: maxLength, through: 1, by: -1) {
                    let first = Array(words[index..<(index + length)])
                    let second = Array(words[(index + length)..<(index + length * 2)])
                    if first == second {
                        words.removeSubrange((index + length)..<(index + length * 2))
                        removed = true
                        break
                    }
                }
            }
            if !removed {
                index += 1
            }
        }

        return words.joined(separator: " ")
    }
}
