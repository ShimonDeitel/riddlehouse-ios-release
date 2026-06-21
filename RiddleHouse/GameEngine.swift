import Foundation

/// One player in the current pass-and-play game.
struct Player: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var points: Int = 0
    var correctCount: Int = 0

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// A single player's answer to the current round's riddle.
struct RoundGuess: Identifiable, Equatable {
    let id = UUID()
    let playerID: UUID
    let playerName: String
    let text: String
    let correct: Bool
    /// Seconds remaining on the timer when the guess was locked in. Higher = faster = ranked first.
    let secondsLeft: Int
}

/// Per-round outcome for one player after scoring.
struct RoundResult: Identifiable, Equatable {
    let id = UUID()
    let playerID: UUID
    let playerName: String
    let guess: String
    let correct: Bool
    let secondsLeft: Int
    /// Rank among the correct answers (1 = fastest). `nil` for wrong/no answer.
    let rank: Int?
    let pointsAwarded: Int
}

/// Pure scoring for a single round.
///
/// Correct answers are ranked by `secondsLeft` (more time left = answered faster = better).
/// Ties (same secondsLeft) share the same rank. Points: 1st place gets `roundCount`-ish weight —
/// we use a simple, predictable scale so the host can explain it: faster correct answers earn more.
enum RoundScorer {
    /// Points for a given rank among `n` correct players: the fastest earns `n + base`, the next
    /// `n - 1 + base`, etc. A correct answer always earns at least `base` (default 2). Wrong = 0.
    static let base = 2

    static func score(guesses: [RoundGuess]) -> [RoundResult] {
        // Sort correct guesses fastest-first (more secondsLeft first); assign dense ranks with ties.
        let correct = guesses.filter { $0.correct }
            .sorted { $0.secondsLeft > $1.secondsLeft }

        // Map playerID -> rank, sharing ranks on equal secondsLeft.
        var rankByPlayer: [UUID: Int] = [:]
        var lastSeconds: Int? = nil
        var currentRank = 0
        for g in correct {
            if g.secondsLeft != lastSeconds {
                currentRank += 1
                lastSeconds = g.secondsLeft
            }
            rankByPlayer[g.playerID] = currentRank
        }

        let correctCount = correct.count

        return guesses.map { g in
            if g.correct, let rank = rankByPlayer[g.playerID] {
                // Highest rank (1) earns the most. points = base + (correctCount - rank + 1)
                let points = base + (correctCount - rank + 1)
                return RoundResult(playerID: g.playerID, playerName: g.playerName,
                                   guess: g.text, correct: true, secondsLeft: g.secondsLeft,
                                   rank: rank, pointsAwarded: points)
            } else {
                return RoundResult(playerID: g.playerID, playerName: g.playerName,
                                   guess: g.text, correct: false, secondsLeft: g.secondsLeft,
                                   rank: nil, pointsAwarded: 0)
            }
        }
    }
}

/// Phase of the host-driven game flow.
enum GamePhase: Equatable {
    case setup          // choosing players
    case reading        // host reads the riddle; players pass the phone
    case answering      // one player typing their answer against the timer
    case roundResults   // showing who got it, ranked
    case finished       // final leaderboard
}

/// Drives a full pass-and-play game: a fixed list of players answer the same riddle each round,
/// the engine scores the round, advances the cumulative leaderboard, and ends after N rounds.
///
/// The host controls the timer in the UI; this object owns game *state* and *scoring*, not the
/// wall-clock countdown (kept separate so it's deterministic and testable).
@MainActor
final class GameEngine: ObservableObject {
    @Published private(set) var phase: GamePhase = .setup
    @Published private(set) var players: [Player] = []
    @Published private(set) var riddles: [Riddle] = []
    @Published private(set) var roundIndex = 0          // 0-based
    @Published private(set) var roundCount = 5
    @Published private(set) var currentRiddle: Riddle?
    /// The player currently entering an answer (pass-and-play moves through everyone each round).
    @Published private(set) var activePlayerIndex = 0
    @Published private(set) var roundGuesses: [RoundGuess] = []
    @Published private(set) var lastResults: [RoundResult] = []

    /// Round number shown to humans (1-based).
    var displayRound: Int { roundIndex + 1 }

    var leaderboard: [Player] {
        players.sorted { ($0.points, $0.correctCount) > ($1.points, $1.correctCount) }
    }

    var winner: Player? { leaderboard.first }

    var isLastPlayerThisRound: Bool { activePlayerIndex >= players.count - 1 }

    // MARK: Setup

    func configure(players names: [String], rounds: Int, riddles pool: [Riddle]) {
        let cleaned = names.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        self.players = cleaned.enumerated().map { Player(name: $0.element.isEmpty ? "Player \($0.offset + 1)" : $0.element) }
        self.roundCount = max(1, rounds)
        // Pick `rounds` distinct riddles (shuffled). If the pool is smaller, allow repeats.
        var picks: [Riddle] = []
        var bag = pool.shuffled()
        for _ in 0..<self.roundCount {
            if bag.isEmpty { bag = pool.shuffled() }
            if !bag.isEmpty { picks.append(bag.removeFirst()) }
        }
        self.riddles = picks
        self.roundIndex = 0
        self.activePlayerIndex = 0
        self.roundGuesses = []
        self.lastResults = []
        self.currentRiddle = picks.first
        self.phase = players.count >= 1 ? .reading : .setup
    }

    /// Host finished reading; first player starts answering.
    func beginAnswering() {
        guard phase == .reading else { return }
        activePlayerIndex = 0
        roundGuesses = []
        phase = .answering
    }

    /// Lock in the active player's answer; returns whether it was correct.
    @discardableResult
    func submitGuess(_ text: String, secondsLeft: Int) -> Bool {
        guard phase == .answering, let riddle = currentRiddle,
              activePlayerIndex < players.count else { return false }
        let player = players[activePlayerIndex]
        let correct = AnswerMatcher.isCorrect(text, for: riddle)
        roundGuesses.append(RoundGuess(playerID: player.id, playerName: player.name,
                                       text: text, correct: correct, secondsLeft: max(0, secondsLeft)))
        if isLastPlayerThisRound {
            scoreRound()
        } else {
            activePlayerIndex += 1
        }
        return correct
    }

    /// Active player ran out of time without answering: record an empty wrong guess and advance.
    func timeOut() {
        submitGuess("", secondsLeft: 0)
    }

    private func scoreRound() {
        let results = RoundScorer.score(guesses: roundGuesses)
        lastResults = results.sorted { (lhs, rhs) in
            // correct first, then by rank ascending, then wrong by name
            switch (lhs.rank, rhs.rank) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.playerName < rhs.playerName
            }
        }
        for r in results {
            if let idx = players.firstIndex(where: { $0.id == r.playerID }) {
                players[idx].points += r.pointsAwarded
                if r.correct { players[idx].correctCount += 1 }
            }
        }
        phase = .roundResults
    }

    /// Move from the round results to the next round, or finish the game.
    func advance() {
        guard phase == .roundResults else { return }
        if roundIndex + 1 >= roundCount {
            phase = .finished
            return
        }
        roundIndex += 1
        currentRiddle = riddles[safe: roundIndex] ?? riddles.last
        activePlayerIndex = 0
        roundGuesses = []
        lastResults = []
        phase = .reading
    }

    /// Final standings as value types for persistence.
    func finalStandings() -> [PlayerStanding] {
        leaderboard.map { PlayerStanding(name: $0.name, points: $0.points, correctCount: $0.correctCount) }
    }

    func reset() {
        phase = .setup
        players = []
        riddles = []
        roundIndex = 0
        currentRiddle = nil
        activePlayerIndex = 0
        roundGuesses = []
        lastResults = []
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
