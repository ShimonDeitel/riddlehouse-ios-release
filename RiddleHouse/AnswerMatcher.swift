import Foundation

/// Pure, deterministic answer checking. A guess counts as correct when, after normalization,
/// it equals any accepted answer — or when an accepted answer is a leading article variant of it
/// (so "clock" matches "a clock"). Kept free of UI/state so it's trivially unit-testable.
enum AnswerMatcher {

    private static let articles: Set<String> = ["a", "an", "the"]

    /// Lowercase, strip punctuation, collapse whitespace, drop a single leading article.
    static func normalize(_ raw: String) -> String {
        let lowered = raw.lowercased()
        // Keep letters, digits and spaces; everything else becomes a space.
        let scalars = lowered.unicodeScalars.map { s -> Character in
            if CharacterSet.alphanumerics.contains(s) { return Character(s) }
            return " "
        }
        let collapsed = String(scalars)
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard let first = collapsed.first else { return "" }
        let words = (articles.contains(first) && collapsed.count > 1)
            ? Array(collapsed.dropFirst())
            : collapsed
        return words.joined(separator: " ")
    }

    /// True when `guess` matches the riddle's canonical answer or any accepted phrasing.
    static func isCorrect(_ guess: String, for riddle: Riddle) -> Bool {
        let g = normalize(guess)
        guard !g.isEmpty else { return false }
        for candidate in riddle.allAnswers where normalize(candidate) == g {
            return true
        }
        return false
    }
}
