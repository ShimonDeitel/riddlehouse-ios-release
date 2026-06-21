import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel

    @State private var showGame = false
    @State private var showLeaderboard = false
    @State private var showSettings = false
    @State private var showPaywall = false

    private var freeCount: Int { appModel.library.count(inPack: RiddleLibrary.freePack) }
    private var totalCount: Int { appModel.library.all.count + (store.isPro ? appModel.customRiddles.count : 0) }

    var body: some View {
        NavigationStack {
            ZStack {
                RHBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        header

                        Button { Haptics.tap(); showGame = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                Text("New Game").font(.headline)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .prominentButton()
                        .accessibilityIdentifier("home-new-game")
                        .padding(.horizontal)

                        statsRow

                        actionCards

                        if !store.isPro {
                            proCard
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("home-settings")
                }
            }
            .fullScreenCover(isPresented: $showGame) { GameFlowView() }
            .sheet(isPresented: $showLeaderboard) { LeaderboardView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.rhAccent)
            Text("Riddle House")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Beat the timer, beat them.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.top, 14)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            MetricTile(value: "\(totalCount)", label: store.isPro ? "Riddles" : "Free riddles")
            MetricTile(value: "\(appModel.totalGames)", label: "Games played")
            MetricTile(value: "30s", label: "Per riddle")
        }
        .padding(.horizontal)
    }

    private var actionCards: some View {
        VStack(spacing: 12) {
            Button { Haptics.tap(); showLeaderboard = true } label: {
                homeRow(icon: "trophy.fill", title: "Leaderboard history",
                        subtitle: appModel.totalGames > 0
                            ? "Last winner: \(appModel.recentGames.first?.winnerName ?? "—")"
                            : "Your past games will appear here")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home-leaderboard")

            Button { Haptics.tap(); showSettings = true } label: {
                homeRow(icon: "gearshape.fill", title: "Settings",
                        subtitle: store.isPro ? "Pro unlocked" : "Theme, restore, more")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    private func homeRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.rhAccent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .rhCard()
    }

    private var proCard: some View {
        Button { Haptics.tap(); showPaywall = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.rhAccent).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Riddle House Pro").font(.headline)
                    Text("Full library, custom riddles, history & share")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(store.displayPrice).font(.subheadline.weight(.bold)).foregroundStyle(Color.rhAccent)
            }
            .padding(16)
            .background(Color.rhAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-pro-card")
        .padding(.horizontal)
    }
}
