import Foundation

/// A single riddle. `answer` is the canonical solution; `accepted` lists extra phrasings that
/// also count as correct. All matching is done case-/whitespace-/punctuation-insensitively
/// (see `AnswerMatcher`).
struct Riddle: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let pack: String
    let question: String
    let answer: String
    let accepted: [String]

    /// `answer` plus every `accepted` phrasing — the full set a guess is checked against.
    var allAnswers: [String] { [answer] + accepted }
}

/// A user-authored riddle (Pro). Stored locally on-device.
struct CustomRiddleDTO: Codable, Equatable {
    var id: String
    var question: String
    var answer: String
    var accepted: [String]

    func asRiddle() -> Riddle {
        Riddle(id: id, pack: "custom", question: question, answer: answer, accepted: accepted)
    }
}

/// The riddle catalog: built-in riddles loaded from the bundled `riddles.json`, grouped by pack.
/// The "starter" pack is free; every other pack is a Pro unlock.
struct RiddleLibrary {
    static let freePack = "starter"

    let all: [Riddle]

    /// Riddles available to the player given their Pro status (plus any custom riddles for Pro).
    func available(isPro: Bool, custom: [Riddle] = []) -> [Riddle] {
        let base = isPro ? all : all.filter { $0.pack == Self.freePack }
        return base + (isPro ? custom : [])
    }

    var packs: [String] {
        var seen = Set<String>(), order: [String] = []
        for r in all where !seen.contains(r.pack) { seen.insert(r.pack); order.append(r.pack) }
        return order
    }

    func count(inPack pack: String) -> Int { all.filter { $0.pack == pack }.count }

    // MARK: Loading

    private struct File: Codable { let version: Int; let riddles: [Riddle] }

    /// Load `riddles.json` from the app bundle. Falls back to a tiny built-in set if the resource
    /// is ever missing so the app never launches empty.
    static func load(bundle: Bundle = .main) -> RiddleLibrary {
        guard let url = bundle.url(forResource: "riddles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data),
              !file.riddles.isEmpty
        else { return RiddleLibrary(all: fallback) }
        return RiddleLibrary(all: file.riddles)
    }

    static let fallback: [Riddle] = [
        Riddle(id: "f1", pack: freePack,
               question: "The more you take, the more you leave behind. What am I?",
               answer: "footsteps", accepted: ["steps", "footprints"]),
        Riddle(id: "f2", pack: freePack,
               question: "What has keys but opens no locks?",
               answer: "keyboard", accepted: ["a keyboard", "piano"])
    ]
}
