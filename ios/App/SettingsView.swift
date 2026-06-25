import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var newEmoji = ""
    @State private var newLabel = ""
    @State private var newValue = 5.0
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            Form {
                themeSection
                emojiSection
                addEmojiSection
                dataSection
                accountSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Palette.bg)
            .navigationTitle("Settings")
        }
    }

    // MARK: Theme

    private var themeSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: themeBinding) {
                Text("System").tag(String?.none)
                Text("Light").tag(String?.some("light"))
                Text("Dark").tag(String?.some("dark"))
            }
            .pickerStyle(.segmented)
        }
    }

    private var themeBinding: Binding<String?> {
        Binding(get: { state.data.theme }, set: { state.setTheme($0) })
    }

    // MARK: Emoji editor

    private var emojiSection: some View {
        Section("Your moods (\(state.data.emojis.count)/\(Defaults.maxEmoji))") {
            ForEach(state.data.emojis) { e in
                HStack {
                    Text(e.emoji).font(.title3)
                    Text(e.label)
                    Spacer()
                    Text("valence \(e.value)").font(.caption).foregroundStyle(Palette.textSoft)
                }
            }
            .onMove { state.moveEmoji(from: $0, to: $1) }
            .onDelete { idx in
                idx.map { state.data.emojis[$0].id }.forEach(state.removeEmoji)
            }
            if state.data.emojis.count <= Defaults.minEmoji {
                Text("Keep at least \(Defaults.minEmoji) moods.")
                    .font(.caption).foregroundStyle(Palette.textSoft)
            }
        }
    }

    private var addEmojiSection: some View {
        Section("Add a mood") {
            TextField("Emoji (e.g. 😴)", text: $newEmoji)
            TextField("Label (e.g. Tired)", text: $newLabel)
            VStack(alignment: .leading) {
                Text("Valence: \(Int(newValue)) (1 low → 10 high)")
                    .font(.caption).foregroundStyle(Palette.textSoft)
                Slider(value: $newValue, in: 1...10, step: 1)
            }
            Button("Add mood") {
                state.addEmoji(newEmoji, label: newLabel, value: Int(newValue))
                newEmoji = ""; newLabel = ""; newValue = 5
            }
            .disabled(newEmoji.isEmpty || newLabel.isEmpty || state.data.emojis.count >= Defaults.maxEmoji)
        }
    }

    // MARK: Data

    private var dataSection: some View {
        Section("Your data") {
            ShareLink("Export as JSON", item: state.exportJSON())
            ShareLink("Export as CSV", item: state.exportCSV())
            Button("Reset all data", role: .destructive) { showReset = true }
        }
        .confirmationDialog("Delete all logs, boosters and custom emojis? This cannot be undone.",
                            isPresented: $showReset, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { state.resetAll() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Account

    private var accountSection: some View {
        Section("Account") {
            if let email = state.userEmail {
                LabeledContent("Signed in", value: email)
            }
            if state.syncing {
                HStack { ProgressView(); Text("Syncing…").foregroundStyle(Palette.textSoft) }
            }
            Button("Sign out", role: .destructive) { state.signOut() }
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            Link("Privacy policy", destination: Config.privacyURL)
            Link("Contact & support", destination: Config.contactURL)
        }
    }
}
