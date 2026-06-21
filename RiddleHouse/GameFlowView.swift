import SwiftUI

/// Top-level game container. Owns one `GameEngine` and a `RoundTimer`, and switches between the
/// phase screens. Presented full-screen from Home.
struct GameFlowView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("riddlehouse.timer.seconds") private var timerSeconds = 30
    @AppStorage("riddlehouse.haptics") private var hapticsEnabled = true

    @StateObject private var engine = GameEngine()
    @StateObject private var timer = RoundTimer()
    @State private var recorded = false

    var body: some View {
        ZStack {
            RHBackground()
            switch engine.phase {
            case .setup:
                SetupView(engine: engine, onCancel: { dismiss() })
            case .reading:
                ReadingView(engine: engine, onCancel: { dismiss() })
            case .answering:
                AnsweringView(engine: engine, timer: timer,
                              seconds: timerSeconds, haptics: hapticsEnabled,
                              onCancel: { dismiss() })
            case .roundResults:
                RoundResultsView(engine: engine, onCancel: { dismiss() })
            case .finished:
                FinishedView(engine: engine, onClose: { dismiss() })
                    .onAppear(perform: recordIfNeeded)
            }
        }
    }

    private func recordIfNeeded() {
        guard !recorded else { return }
        recorded = true
        appModel.recordGame(roundCount: engine.roundCount, standings: engine.finalStandings())
    }
}

// MARK: - Setup

private struct SetupView: View {
    @ObservedObject var engine: GameEngine
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel
    let onCancel: () -> Void

    @State private var names: [String] = ["", ""]
    @State private var rounds = 5
    @State private var showPaywall = false

    private let roundOptions = [3, 5, 7, 10]

    private var pool: [Riddle] { appModel.availableRiddles(isPro: store.isPro) }
    private var validPlayers: Int { names.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count }
    private var canStart: Bool { validPlayers >= 2 }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        ForEach(names.indices, id: \.self) { i in
                            PlayerRow(name: $names[i], index: i, canRemove: names.count > 2) {
                                names.remove(at: i)
                            }
                        }
                        if names.count < 8 {
                            Button { Haptics.tap(); names.append("") } label: {
                                Label("Add player", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .softButton()
                            .accessibilityIdentifier("add-player")
                        }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Rounds").font(.headline)
                        HStack(spacing: 10) {
                            ForEach(roundOptions, id: \.self) { n in
                                RoundCountChip(value: n, selected: rounds == n) { rounds = n }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    Text(store.isPro
                         ? "\(pool.count) riddles in the deck."
                         : "Starter pack: \(pool.count) riddles. Unlock Pro for the full library.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if !store.isPro {
                        Button { showPaywall = true } label: {
                            Text("See Pro library")
                        }
                        .softButton()
                    }
                }
                .padding(.vertical, 8)
            }

            VStack(spacing: 6) {
                Button { start() } label: {
                    Text("Start game").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .prominentButton()
                .disabled(!canStart)
                .opacity(canStart ? 1 : 0.5)
                .accessibilityIdentifier("start-game")
                if !canStart {
                    Text("Add at least two players to start.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var header: some View {
        HStack {
            Button { onCancel() } label: {
                Image(systemName: "xmark").font(.headline).foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("setup-close")
            Spacer()
            Text("Players").font(.headline)
            Spacer()
            Image(systemName: "xmark").font(.headline).opacity(0)
        }
        .padding()
    }

    private func start() {
        Haptics.success()
        engine.configure(players: names, rounds: rounds, riddles: pool)
    }
}

// MARK: - Reading (host reads aloud, then passes the phone)

private struct ReadingView: View {
    @ObservedObject var engine: GameEngine
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(round: engine.displayRound, total: engine.roundCount, onCancel: onCancel)
            Spacer()
            VStack(spacing: 18) {
                Text("Round \(engine.displayRound)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.rhAccent)
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 30, weight: .semibold)).foregroundStyle(Color.rhAccent)
                Text("Host: read the riddle aloud")
                    .font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                if let riddle = engine.currentRiddle {
                    Text(riddle.question)
                        .font(.title2.weight(.medium))
                        .multilineTextAlignment(.center)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color.rhCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                Text("Everyone gets the same riddle. Each player answers in turn against a 30-second timer.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 22)
            Spacer()
            Button { Haptics.tap(); engine.beginAnswering() } label: {
                Text("Start answering").frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .prominentButton()
            .padding()
            .accessibilityIdentifier("begin-answering")
        }
    }
}

// MARK: - Answering (one player at a time, against the timer)

private struct AnsweringView: View {
    @ObservedObject var engine: GameEngine
    @ObservedObject var timer: RoundTimer
    let seconds: Int
    let haptics: Bool
    let onCancel: () -> Void

    @State private var guess = ""
    @FocusState private var focused: Bool
    @State private var currentPlayerID: UUID?

    private var activeName: String {
        guard engine.activePlayerIndex < engine.players.count else { return "" }
        return engine.players[engine.activePlayerIndex].name
    }

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(round: engine.displayRound, total: engine.roundCount, onCancel: onCancel)

            ScrollView {
                VStack(spacing: 20) {
                    Text(activeName.isEmpty ? "Your turn" : "\(activeName)'s turn")
                        .font(.title2.weight(.bold))
                        .padding(.top, 6)
                        .accessibilityIdentifier("active-player")

                    TimerRing(fraction: timer.fraction, secondsRemaining: timer.secondsRemaining)

                    if let riddle = engine.currentRiddle {
                        Text(riddle.question)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    TextField("Type your answer", text: $guess)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($focused)
                        .font(.title3)
                        .padding(14)
                        .background(Color.rhField, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)
                        .onSubmit(submit)
                        .accessibilityIdentifier("answer-field")

                    Button { submit() } label: {
                        Text("Lock in answer").frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .prominentButton()
                    .padding(.horizontal)
                    .accessibilityIdentifier("lock-in")

                    Text("Tip: don't let the others see what you type.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .onAppear { startTurn() }
        .onChange(of: engine.activePlayerIndex) { _, _ in startTurn() }
    }

    private func startTurn() {
        guard engine.phase == .answering else { return }
        guess = ""
        timer.hapticsEnabled = haptics
        timer.onExpire = { handleTimeout() }
        timer.start(seconds: seconds)
        currentPlayerID = engine.players[safe: engine.activePlayerIndex]?.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
    }

    private func submit() {
        guard engine.phase == .answering else { return }
        let secondsLeft = timer.secondsRemaining
        timer.stop()
        focused = false
        let correct = engine.submitGuess(guess, secondsLeft: secondsLeft)
        if haptics { correct ? Haptics.success() : Haptics.soft() }
        // If engine advanced to next player, startTurn fires via onChange; if it scored the round,
        // phase changes and this view is replaced.
    }

    private func handleTimeout() {
        guard engine.phase == .answering else { return }
        focused = false
        engine.timeOut()
    }
}

// MARK: - Round results

private struct RoundResultsView: View {
    @ObservedObject var engine: GameEngine
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(round: engine.displayRound, total: engine.roundCount, onCancel: onCancel)
            ScrollView {
                VStack(spacing: 16) {
                    if let riddle = engine.currentRiddle {
                        VStack(spacing: 6) {
                            Text("Answer").font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(riddle.answer.capitalized)
                                .font(.title2.weight(.bold)).foregroundStyle(Color.rhAccent)
                        }
                        .padding(.vertical, 14).frame(maxWidth: .infinity)
                        .background(Color.rhAccent.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal)
                    }

                    VStack(spacing: 10) {
                        ForEach(engine.lastResults) { r in
                            RoundResultRow(result: r)
                        }
                    }
                    .padding(.horizontal)

                    miniLeaderboard
                }
                .padding(.vertical, 8)
            }
            Button { Haptics.tap(); engine.advance() } label: {
                Text(engine.displayRound >= engine.roundCount ? "See final results" : "Next round")
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .prominentButton()
            .padding()
            .accessibilityIdentifier("next-round")
        }
    }

    private var miniLeaderboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Standings").font(.headline).padding(.horizontal)
            VStack(spacing: 8) {
                ForEach(Array(engine.leaderboard.enumerated()), id: \.element.id) { idx, p in
                    LeaderboardRow(rank: idx + 1, name: p.name, points: p.points, correctCount: p.correctCount)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 6)
    }
}

// MARK: - Finished

private struct FinishedView: View {
    @ObservedObject var engine: GameEngine
    @EnvironmentObject var store: Store
    let onClose: () -> Void
    @State private var showShare = false

    private var shareText: String {
        var lines = ["Riddle House — final scores", ""]
        for (i, p) in engine.leaderboard.enumerated() {
            lines.append("\(i + 1). \(p.name) — \(p.points) pts (\(p.correctCount) correct)")
        }
        lines.append("")
        lines.append("Beat the timer, beat them.")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 48, weight: .semibold)).foregroundStyle(Color.rhAccent)
                        Text("\(engine.winner?.name ?? "Winner") wins!")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text("\(engine.winner?.points ?? 0) points")
                            .font(.headline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 30)

                    VStack(spacing: 10) {
                        ForEach(Array(engine.leaderboard.enumerated()), id: \.element.id) { idx, p in
                            LeaderboardRow(rank: idx + 1, name: p.name, points: p.points, correctCount: p.correctCount)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 12)
            }
            VStack(spacing: 10) {
                if store.isPro {
                    Button { Haptics.tap(); showShare = true } label: {
                        Label("Share results", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .softButton()
                    .accessibilityIdentifier("share-results")
                }
                Button { Haptics.tap(); onClose() } label: {
                    Text("Done").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .prominentButton()
                .accessibilityIdentifier("game-done")
            }
            .padding()
        }
        .sheet(isPresented: $showShare) { ShareSheet(items: [shareText]) }
    }
}

// MARK: - Shared header

private struct GameHeader: View {
    let round: Int
    let total: Int
    let onCancel: () -> Void
    var body: some View {
        HStack {
            Button { onCancel() } label: {
                Image(systemName: "xmark").font(.headline).foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("game-cancel")
            Spacer()
            Text("Round \(round) of \(total)").font(.subheadline.weight(.semibold))
            Spacer()
            Image(systemName: "xmark").font(.headline).opacity(0)
        }
        .padding()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
