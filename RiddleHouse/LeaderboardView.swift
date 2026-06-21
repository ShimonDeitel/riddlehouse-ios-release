import SwiftUI

/// Leaderboard history — every finished game with its winner and final standings.
/// Free users see the most recent game; Pro unlocks the full history.
struct LeaderboardView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    private var visibleGames: [GameRecord] {
        store.isPro ? appModel.recentGames : Array(appModel.recentGames.prefix(1))
    }
    private var hiddenCount: Int {
        max(0, appModel.recentGames.count - visibleGames.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RHBackground()
                if appModel.recentGames.isEmpty {
                    empty
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(visibleGames) { game in
                                GameHistoryCard(game: game)
                            }
                            if hiddenCount > 0 {
                                lockedHistory
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 44, weight: .semibold)).foregroundStyle(.secondary)
            Text("No games yet").font(.title3.weight(.semibold))
            Text("Play a game and the final standings will be saved here.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var lockedHistory: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.rhAccent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(hiddenCount) more game\(hiddenCount == 1 ? "" : "s") in your history")
                        .font(.headline)
                    Text("Unlock Pro to see your full leaderboard history.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.rhAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct GameHistoryCard: View {
    let game: GameRecord

    private var dateText: String {
        game.date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dateText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(game.roundCount) rounds").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(game.standings.enumerated()), id: \.element.id) { idx, s in
                LeaderboardRow(rank: idx + 1, name: s.name, points: s.points, correctCount: s.correctCount)
            }
        }
        .padding(14)
        .background(Color.rhCard2, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
