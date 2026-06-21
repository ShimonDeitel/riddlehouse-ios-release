import SwiftUI

/// The big visible countdown ring used during the answering phase. Flat Apple-blue stroke that
/// drains as time runs out, turning warning-orange in the final five seconds. No gradients.
struct TimerRing: View {
    /// 1 -> 0 fraction of time remaining.
    var fraction: Double
    var secondsRemaining: Int
    var size: CGFloat = 220

    private var urgent: Bool { secondsRemaining <= 5 }
    private var ringColor: Color { urgent ? Color(hex: "#FF9500") : .rhAccent }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.rhHair.opacity(0.5), lineWidth: 14)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.9), value: fraction)
            VStack(spacing: 2) {
                Text("\(secondsRemaining)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(ringColor)
                    .contentTransition(.numericText())
                Text("seconds")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityIdentifier("timer-ring")
    }
}

/// A removable player name field row used on the Setup screen.
struct PlayerRow: View {
    @Binding var name: String
    let index: Int
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.rhAccent.opacity(0.15)).frame(width: 32, height: 32)
                Text("\(index + 1)").font(.subheadline.weight(.bold)).foregroundStyle(Color.rhAccent)
            }
            TextField("Player \(index + 1)", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .accessibilityIdentifier("player-field-\(index)")
            if canRemove {
                Button { onRemove() } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("player-remove-\(index)")
            }
        }
        .padding(.vertical, 6).padding(.horizontal, 14)
        .background(Color.rhCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A chip used to pick the number of rounds in a game.
struct RoundCountChip: View {
    let value: Int
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(.headline.weight(.semibold))
                .frame(width: 48, height: 44)
                .background(selected ? Color.rhAccent : Color.rhCard,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rounds-\(value)")
    }
}

/// One row in the per-round results list.
struct RoundResultRow: View {
    let result: RoundResult
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(result.correct ? Color.rhAccent : Color.rhCard2)
                    .frame(width: 34, height: 34)
                if let rank = result.rank {
                    Text("\(rank)").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                } else {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(result.playerName).font(.headline)
                Text(result.correct
                     ? "Correct in \(result.secondsLeft)s left"
                     : (result.guess.isEmpty ? "No answer" : "Said \u{201C}\(result.guess)\u{201D}"))
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(result.pointsAwarded > 0 ? "+\(result.pointsAwarded)" : "0")
                .font(.headline.weight(.bold))
                .foregroundStyle(result.correct ? Color.rhAccent : .secondary)
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(Color.rhCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// One row in the cumulative leaderboard.
struct LeaderboardRow: View {
    let rank: Int
    let name: String
    let points: Int
    let correctCount: Int
    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(rank == 1 ? Color.rhAccent : .secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text("\(correctCount) correct").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(points)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("pts").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .background(
            rank == 1 ? Color.rhAccent.opacity(0.10) : Color.rhCard,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

/// A small labelled metric tile.
struct MetricTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.rhAccent)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.rhCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Wraps UIActivityViewController so we can share game results text.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
