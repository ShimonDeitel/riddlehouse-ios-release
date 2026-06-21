import Foundation
import SwiftData

/// A finished pass-and-play game, persisted locally on-device. All properties have defaults and
/// there are no unique constraints or non-optional relationships.
@Model
final class GameRecord {
    var id: UUID = UUID()
    var date: Date = Date.now
    var roundCount: Int = 5
    var winnerName: String = ""
    var winnerPoints: Int = 0
    /// Final standings encoded as JSON ([PlayerStanding]) so we keep simple value types.
    var standingsData: Data = Data()

    init(id: UUID = UUID(), date: Date = .now, roundCount: Int = 5,
         winnerName: String = "", winnerPoints: Int = 0, standingsData: Data = Data()) {
        self.id = id
        self.date = date
        self.roundCount = roundCount
        self.winnerName = winnerName
        self.winnerPoints = winnerPoints
        self.standingsData = standingsData
    }

    var standings: [PlayerStanding] {
        (try? JSONDecoder().decode([PlayerStanding].self, from: standingsData)) ?? []
    }
}

/// A player's final result in a completed game (value type, stored inside GameRecord).
struct PlayerStanding: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var points: Int
    var correctCount: Int
}
