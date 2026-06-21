import XCTest
import SwiftData
@testable import RiddleHouse

/// Unit tests for the pure game logic: answer matching, per-round scoring (correct ranked by
/// speed), the cumulative leaderboard, Pro gating of custom riddles, and the bundled dataset.
@MainActor
final class RiddleHouseLogicTests: XCTestCase {

    private func memoryModel() -> ModelContainer {
        try! ModelContainer(for: GameRecord.self,
                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private let sampleRiddle = Riddle(id: "t1", pack: "starter",
                                      question: "What has keys but opens no locks?",
                                      answer: "keyboard", accepted: ["a keyboard", "piano"])

    // MARK: AnswerMatcher

    func testAnswerMatchingIsForgiving() {
        XCTAssertTrue(AnswerMatcher.isCorrect("keyboard", for: sampleRiddle))
        XCTAssertTrue(AnswerMatcher.isCorrect("Keyboard", for: sampleRiddle))      // case
        XCTAssertTrue(AnswerMatcher.isCorrect("  keyboard  ", for: sampleRiddle))  // whitespace
        XCTAssertTrue(AnswerMatcher.isCorrect("A keyboard", for: sampleRiddle))    // leading article
        XCTAssertTrue(AnswerMatcher.isCorrect("the keyboard!", for: sampleRiddle)) // punctuation + article
        XCTAssertTrue(AnswerMatcher.isCorrect("piano", for: sampleRiddle))         // accepted alt
        XCTAssertFalse(AnswerMatcher.isCorrect("guitar", for: sampleRiddle))       // wrong
        XCTAssertFalse(AnswerMatcher.isCorrect("", for: sampleRiddle))             // empty
    }

    func testNormalizeDropsOnlyLeadingArticle() {
        XCTAssertEqual(AnswerMatcher.normalize("The Cat"), "cat")
        XCTAssertEqual(AnswerMatcher.normalize("a a"), "a")          // keeps remaining word
        XCTAssertEqual(AnswerMatcher.normalize("the"), "the")       // lone article isn't dropped
        XCTAssertEqual(AnswerMatcher.normalize("e-mail!"), "e mail")
    }

    // MARK: RoundScorer — correct ranked by speed

    func testRoundScoringRanksFasterCorrectHigher() {
        let p1 = UUID(), p2 = UUID(), p3 = UUID()
        let guesses = [
            RoundGuess(playerID: p1, playerName: "Ava", text: "keyboard", correct: true, secondsLeft: 10),
            RoundGuess(playerID: p2, playerName: "Noah", text: "keyboard", correct: true, secondsLeft: 25),
            RoundGuess(playerID: p3, playerName: "Mia", text: "guitar", correct: false, secondsLeft: 5)
        ]
        let results = RoundScorer.score(guesses: guesses)
        let byID = Dictionary(uniqueKeysWithValues: results.map { ($0.playerID, $0) })

        // Noah answered with more time left => rank 1; Ava rank 2; Mia wrong => no rank, 0 points.
        XCTAssertEqual(byID[p2]?.rank, 1)
        XCTAssertEqual(byID[p1]?.rank, 2)
        XCTAssertNil(byID[p3]?.rank)
        XCTAssertEqual(byID[p3]?.pointsAwarded, 0)
        // Faster correct earns strictly more than slower correct.
        XCTAssertGreaterThan(byID[p2]!.pointsAwarded, byID[p1]!.pointsAwarded)
        // Every correct answer earns at least the base.
        XCTAssertGreaterThanOrEqual(byID[p1]!.pointsAwarded, RoundScorer.base)
    }

    func testRoundScoringSharesRankOnTie() {
        let p1 = UUID(), p2 = UUID()
        let guesses = [
            RoundGuess(playerID: p1, playerName: "A", text: "keyboard", correct: true, secondsLeft: 20),
            RoundGuess(playerID: p2, playerName: "B", text: "keyboard", correct: true, secondsLeft: 20)
        ]
        let results = RoundScorer.score(guesses: guesses)
        XCTAssertEqual(results.first(where: { $0.playerID == p1 })?.rank, 1)
        XCTAssertEqual(results.first(where: { $0.playerID == p2 })?.rank, 1)
        // Tied players earn equal points.
        XCTAssertEqual(results.first(where: { $0.playerID == p1 })?.pointsAwarded,
                       results.first(where: { $0.playerID == p2 })?.pointsAwarded)
    }

    // MARK: GameEngine — full game flow

    func testFullGameAccumulatesLeaderboardAndFinishes() {
        let engine = GameEngine()
        let pool = [
            Riddle(id: "g1", pack: "starter", question: "Q1", answer: "cat", accepted: []),
            Riddle(id: "g2", pack: "starter", question: "Q2", answer: "dog", accepted: [])
        ]
        engine.configure(players: ["Ava", "Noah"], rounds: 2, riddles: pool)
        XCTAssertEqual(engine.phase, .reading)
        XCTAssertEqual(engine.players.count, 2)
        XCTAssertEqual(engine.roundCount, 2)

        // Round 1
        engine.beginAnswering()
        XCTAssertEqual(engine.phase, .answering)
        let r1 = engine.currentRiddle!
        // Ava correct fast, Noah wrong.
        engine.submitGuess(r1.answer, secondsLeft: 28)
        XCTAssertEqual(engine.phase, .answering) // still Noah's turn
        engine.submitGuess("wrong", secondsLeft: 20)
        XCTAssertEqual(engine.phase, .roundResults)
        XCTAssertEqual(engine.winner?.name, "Ava")

        // Advance to round 2
        engine.advance()
        XCTAssertEqual(engine.phase, .reading)
        XCTAssertEqual(engine.displayRound, 2)
        engine.beginAnswering()
        let r2 = engine.currentRiddle!
        engine.submitGuess("nope", secondsLeft: 25)        // Ava wrong
        engine.submitGuess(r2.answer, secondsLeft: 22)     // Noah correct
        XCTAssertEqual(engine.phase, .roundResults)

        // Finish
        engine.advance()
        XCTAssertEqual(engine.phase, .finished)
        // Each won one round; leaderboard is non-empty and totals are sane.
        XCTAssertEqual(engine.leaderboard.count, 2)
        XCTAssertGreaterThan(engine.leaderboard.first!.points, 0)
        let standings = engine.finalStandings()
        XCTAssertEqual(standings.count, 2)
        XCTAssertEqual(standings.map(\.points).reduce(0, +),
                       engine.players.map(\.points).reduce(0, +))
    }

    func testTimeOutCountsAsWrongAndAdvances() {
        let engine = GameEngine()
        let pool = [Riddle(id: "g1", pack: "starter", question: "Q", answer: "cat", accepted: [])]
        engine.configure(players: ["A", "B"], rounds: 1, riddles: pool)
        engine.beginAnswering()
        engine.timeOut()                       // A times out
        XCTAssertEqual(engine.phase, .answering) // B still to go
        engine.submitGuess("cat", secondsLeft: 5)
        XCTAssertEqual(engine.phase, .roundResults)
        // B (correct) leads A (timed out, 0).
        XCTAssertEqual(engine.winner?.name, "B")
    }

    // MARK: Library + Pro gating

    func testLibraryLoadsBundledRiddlesAndStarterPackIsFree() {
        let lib = RiddleLibrary.load(bundle: Bundle(for: Self.self))
        // The test bundle may not embed the app's JSON; the loader falls back, but either way the
        // starter pack must be non-empty and gating must hold.
        XCTAssertFalse(lib.all.isEmpty)
        let free = lib.available(isPro: false)
        XCTAssertFalse(free.isEmpty)
        XCTAssertTrue(free.allSatisfy { $0.pack == RiddleLibrary.freePack })
        // Pro sees at least as many riddles as a free user.
        XCTAssertGreaterThanOrEqual(lib.available(isPro: true).count, free.count)
    }

    func testCustomRiddleNotPersistedWithoutPro() {
        let model = AppModel(container: memoryModel(),
                             library: RiddleLibrary(all: RiddleLibrary.fallback))
        // No store attached, so not Pro, so it must not persist.
        let r = model.addCustomRiddle(question: "Q?", answer: "a", accepted: [])
        XCTAssertNil(r)
        XCTAssertTrue(model.customRiddles.isEmpty)
        XCTAssertEqual(model.availableRiddles(isPro: false).count,
                       RiddleLibrary.fallback.filter { $0.pack == RiddleLibrary.freePack }.count)
    }

    func testRecordGameUpdatesHistory() {
        let model = AppModel(container: memoryModel(),
                             library: RiddleLibrary(all: RiddleLibrary.fallback))
        XCTAssertEqual(model.totalGames, 0)
        model.recordGame(roundCount: 5, standings: [
            PlayerStanding(name: "Ava", points: 12, correctCount: 4),
            PlayerStanding(name: "Noah", points: 7, correctCount: 2)
        ])
        XCTAssertEqual(model.totalGames, 1)
        XCTAssertEqual(model.recentGames.first?.winnerName, "Ava")
        XCTAssertEqual(model.recentGames.first?.standings.count, 2)
    }
}
