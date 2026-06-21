import SwiftUI

/// Pro feature: write your own riddle. Question + canonical answer + optional comma-separated
/// alternative answers that also count as correct.
struct CustomRiddlesView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var question = ""
    @State private var answer = ""
    @State private var alternatives = ""
    @State private var savedNotice = false

    private var canSave: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        store.isPro
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Riddle") {
                    TextField("Question", text: $question, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("custom-question")
                }
                Section {
                    TextField("Main answer", text: $answer)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("custom-answer")
                    TextField("Also accept (comma separated)", text: $alternatives)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Answer")
                } footer: {
                    Text("Answers are matched loosely: capitalization, spacing, punctuation and a leading \u{201C}a/an/the\u{201D} are ignored.")
                }

                if !appModel.customRiddles.isEmpty {
                    Section("Your riddles") {
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
                }
            }
            .navigationTitle("Custom Riddle")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.rhAccent)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("custom-save")
                }
            }
            .overlay(alignment: .bottom) {
                if savedNotice {
                    Text("Saved")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Color.rhAccent, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.bottom, 24)
                        .transition(.opacity)
                }
            }
        }
    }

    private func save() {
        let alts = alternatives.split(separator: ",").map { String($0) }
        let result = appModel.addCustomRiddle(question: question, answer: answer, accepted: alts)
        guard result != nil else { return }
        Haptics.success()
        question = ""; answer = ""; alternatives = ""
        withAnimation { savedNotice = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { savedNotice = false }
        }
    }
}
