import Foundation
import Combine

/// A simple visible countdown for the answering phase. Drives the on-screen ring and fires
/// `onExpire` once when it hits zero. Deliberately separate from `GameEngine` so the engine stays
/// deterministic and unit-testable while the wall clock lives here.
@MainActor
final class RoundTimer: ObservableObject {
    @Published private(set) var secondsRemaining = 0
    @Published private(set) var isRunning = false

    var total = 30
    var hapticsEnabled = true
    var onExpire: (() -> Void)?

    private var timer: AnyCancellable?

    /// Fraction of time remaining (1 -> 0), for the progress ring.
    var fraction: Double {
        total > 0 ? Double(secondsRemaining) / Double(total) : 0
    }

    func start(seconds: Int) {
        total = max(1, seconds)
        secondsRemaining = total
        isRunning = true
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
    }

    private func tick() {
        guard isRunning else { return }
        if secondsRemaining > 0 { secondsRemaining -= 1 }
        if hapticsEnabled, secondsRemaining <= 5, secondsRemaining > 0 {
            Haptics.tick(intensity: 0.7)
        }
        if secondsRemaining <= 0 {
            stop()
            if hapticsEnabled { Haptics.warning() }
            onExpire?()
        }
    }
}
