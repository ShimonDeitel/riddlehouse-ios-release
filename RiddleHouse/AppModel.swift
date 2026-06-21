import Foundation
import SwiftData
import SwiftUI

/// App state: owns the local SwiftData store, loads the bundled riddle library, persists custom
/// riddles (Pro), and records finished games for the leaderboard history. History stats are always
/// derived — never stored truth.
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    let library: RiddleLibrary

    @Published private(set) var customRiddles: [Riddle] = []
    @Published private(set) var totalGames = 0
    @Published private(set) var recentGames: [GameRecord] = []

    private let kCustom = "riddlehouse.custom.riddles"

    init(container: ModelContainer, library: RiddleLibrary = .load()) {
        self.container = container
        self.library = library
        loadCustom()
        #if DEBUG
        seedIfRequested()
        #endif
        refresh()
    }

    // MARK: Container (local-only on-device persistence)

    static func makeContainer() -> ModelContainer {
        let schema = Schema([GameRecord.self])
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        // Last resort so the app never crashes on launch.
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    // MARK: Riddle pool

    /// The riddles available to start a game, honoring Pro gating + custom riddles.
    func availableRiddles(isPro: Bool) -> [Riddle] {
        library.available(isPro: isPro, custom: isPro ? customRiddles : [])
    }

    // MARK: Game history

    func recordGame(roundCount: Int, standings: [PlayerStanding]) {
        let ctx = container.mainContext
        let winner = standings.first
        let data = (try? JSONEncoder().encode(standings)) ?? Data()
        ctx.insert(GameRecord(roundCount: roundCount,
                              winnerName: winner?.name ?? "",
                              winnerPoints: winner?.points ?? 0,
                              standingsData: data))
        try? ctx.save()
        refresh()
    }

    func refresh() {
        let all = (try? container.mainContext.fetch(
            FetchDescriptor<GameRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        totalGames = all.count
        recentGames = all
    }

    // MARK: Custom riddles (Pro)

    private func loadCustom() {
        guard let data = UserDefaults.standard.data(forKey: kCustom),
              let dtos = try? JSONDecoder().decode([CustomRiddleDTO].self, from: data) else { return }
        customRiddles = dtos
            .filter { !$0.question.trimmingCharacters(in: .whitespaces).isEmpty
                   && !$0.answer.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.asRiddle() }
    }

    private func persistCustom() {
        let dtos = customRiddles.map {
            CustomRiddleDTO(id: $0.id, question: $0.question, answer: $0.answer, accepted: $0.accepted)
        }
        if let data = try? JSONEncoder().encode(dtos) {
            UserDefaults.standard.set(data, forKey: kCustom)
        }
    }

    @discardableResult
    func addCustomRiddle(question: String, answer: String, accepted: [String]) -> Riddle? {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !a.isEmpty else { return nil }
        // Defense-in-depth: custom riddles are a Pro bonus — never persist one for a free user,
        // even if a caller reaches here past the UI gate.
        guard store?.isPro == true else { return nil }
        let cleanedAccepted = accepted
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let riddle = Riddle(id: "custom-\(UUID().uuidString.prefix(8))",
                            pack: "custom", question: q, answer: a, accepted: cleanedAccepted)
        customRiddles.append(riddle)
        persistCustom()
        return riddle
    }

    func deleteCustomRiddle(id: String) {
        customRiddles.removeAll { $0.id == id }
        persistCustom()
    }

    /// Erase all on-device data (used by Delete Account).
    func deleteAllData() {
        let ctx = container.mainContext
        try? ctx.delete(model: GameRecord.self)
        try? ctx.save()
        customRiddles.removeAll()
        UserDefaults.standard.removeObject(forKey: kCustom)
        refresh()
    }

    // MARK: DEBUG seeding (compiled out of Release)

    #if DEBUG
    private func seedIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let n = env["RIDDLEHOUSE_SEED"].flatMap(Int.init), n > 0 else { return }
        let ctx = container.mainContext
        if ((try? ctx.fetch(FetchDescriptor<GameRecord>()))?.isEmpty ?? true) {
            let names = ["Ava", "Noah", "Mia", "Leo"]
            let cal = Calendar.current
            for offset in 0..<n {
                let standings = names.enumerated().map {
                    PlayerStanding(name: $0.element, points: (names.count - $0.offset) * 5,
                                   correctCount: names.count - $0.offset)
                }
                let data = (try? JSONEncoder().encode(standings)) ?? Data()
                let date = cal.date(byAdding: .day, value: -offset, to: .now) ?? .now
                ctx.insert(GameRecord(date: date, roundCount: 5,
                                      winnerName: standings.first?.name ?? "",
                                      winnerPoints: standings.first?.points ?? 0,
                                      standingsData: data))
            }
            try? ctx.save()
        }
    }
    #endif
}
