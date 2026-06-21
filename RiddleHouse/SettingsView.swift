import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("riddlehouse.theme") private var themeRaw = AppTheme.system.rawValue
    @AppStorage("riddlehouse.haptics") private var hapticsEnabled = true
    @AppStorage("riddlehouse.timer.seconds") private var timerSeconds = 30

    @State private var showPaywall = false
    @State private var showCustom = false
    @State private var showDeleteConfirm = false
    @State private var restoreMessage: String?

    private let timerOptions = [20, 30, 45, 60]

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Riddle House \(v)"
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection
                appearanceSection
                gameSection
                if store.isPro { customRiddlesSection }
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(Color.rhAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showCustom) { CustomRiddlesView() }
            .alert("Erase Data?", isPresented: $showDeleteConfirm) {
                Button("Erase", role: .destructive) {
                    appModel.deleteAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This erases your games and custom riddles on this device. This can't be undone.")
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Label("Riddle House Pro", systemImage: "sparkles")
                    Spacer()
                    Text("Unlocked").foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Haptics.tap(); showPaywall = true
                } label: {
                    HStack {
                        Label("Unlock Pro", systemImage: "sparkles")
                        Spacer()
                        Text(store.displayPrice).foregroundStyle(.secondary)
                    }
                }
                Button("Restore Purchase") {
                    Task {
                        await store.restore()
                        restoreMessage = store.isPro ? "Restored." : "No previous purchase found."
                    }
                }
                if let restoreMessage {
                    Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } footer: {
            if !store.isPro {
                Text("One-time purchase. Full riddle library, custom riddles, leaderboard history and share.")
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeRaw) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var gameSection: some View {
        Section("Game") {
            Toggle("Haptics", isOn: $hapticsEnabled)
            Picker("Timer per riddle", selection: $timerSeconds) {
                ForEach(timerOptions, id: \.self) { Text("\($0)s").tag($0) }
            }
        }
    }

    private var customRiddlesSection: some View {
        Section("Custom riddles") {
            if appModel.customRiddles.isEmpty {
                Text("No custom riddles yet.").foregroundStyle(.secondary)
            } else {
                ForEach(appModel.customRiddles) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.question).font(.subheadline).lineLimit(2)
                        Text("Answer: \(r.answer)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onDelete { idx in
                    idx.map { appModel.customRiddles[$0].id }.forEach(appModel.deleteCustomRiddle)
                }
            }
            Button {
                Haptics.tap(); showCustom = true
            } label: {
                Label("Add riddle", systemImage: "plus")
            }
            .accessibilityIdentifier("settings-add-riddle")
        }
    }

    private var aboutSection: some View {
        Section {
            Button("Erase Data", role: .destructive) { showDeleteConfirm = true }
            Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/riddlehouse-site/privacy.html")!)
        } footer: {
            Text(version).frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
        }
    }
}
