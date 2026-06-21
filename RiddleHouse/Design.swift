import SwiftUI
import UIKit

// MARK: - Minimalist, Apple-native color system
// Flat surfaces, system semantic colors (so Light AND Dark both look right),
// a single Apple-blue accent. No gradients.

extension Color {
    static let rhAccent = Color(hex: "#007AFF")          // the single accent
    static let rhCard = Color(uiColor: .secondarySystemBackground)
    static let rhCard2 = Color(uiColor: .tertiarySystemBackground)
    static let rhField = Color(uiColor: .tertiarySystemFill)
    static let rhHair = Color(uiColor: .separator)
}

// MARK: - Flat surfaces (cards / pills / buttons)

extension View {
    func rhCard(cornerRadius: CGFloat = 20) -> some View {
        self.padding(16)
            .background(Color.rhCard, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func rhPill() -> some View {
        self.padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.rhCard, in: Capsule())
    }

    /// Primary action — a clean, flat Apple-blue filled capsule.
    func prominentButton() -> some View { self.buttonStyle(FilledAccentButtonStyle()) }
    /// Secondary action — flat tinted capsule.
    func softButton() -> some View { self.buttonStyle(SoftButtonStyle()) }
}

struct FilledAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 22)
            .background(Color.rhAccent, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.medium))
            .foregroundStyle(Color.rhAccent)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(Color.rhCard, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Background (flat, adapts to light/dark)

struct RHBackground: View {
    var body: some View { Color(uiColor: .systemBackground).ignoresSafeArea() }
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }

    /// A light pulse used as each second of the round timer ticks down.
    static func tick(intensity: CGFloat = 0.5) {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: intensity)
    }
}

// MARK: - Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
