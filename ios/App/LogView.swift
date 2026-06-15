import SwiftUI

struct LogView: View {
    @EnvironmentObject var state: AppState
    @State private var pendingEmoji: Emoji?     // tapped emoji awaiting optional note
    @State private var note = ""

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How are you feeling?")
                        .font(.title3.weight(.medium))
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(state.data.emojis) { e in
                            Button {
                                pendingEmoji = e
                                note = ""
                            } label: {
                                VStack(spacing: 4) {
                                    Text(e.emoji).font(.system(size: 34))
                                    Text(e.label).font(.caption2).foregroundStyle(Palette.textSoft)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Palette.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)

                    boostSection
                    todaySection
                }
                .padding(16)
            }
            .background(Palette.bg)
            .navigationTitle("moodring")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { state.ensureTodayBoost() }
        .sheet(item: $pendingEmoji) { emoji in
            noteSheet(for: emoji)
        }
    }

    // MARK: Today's boost

    @ViewBuilder private var boostSection: some View {
        Text("TODAY’S BOOST").sectionTitle()
        if let tb = state.currentBoost, let text = state.boosterText(id: tb.id) {
            VStack(alignment: .leading, spacing: 14) {
                Text(text)
                    .font(.headline)
                    .strikethrough(tb.done, color: Palette.accent)
                    .foregroundStyle(tb.done ? Palette.textSoft : Palette.text)
                HStack(spacing: 10) {
                    Button { state.shuffleBoost() } label: {
                        Text("🔀 Shuffle").frame(maxWidth: .infinity)
                    }.buttonStyle(GhostButton())
                    Button { state.toggleBoostDone() } label: {
                        Text(tb.done ? "✓ Done today" : "Mark done").frame(maxWidth: .infinity)
                    }.buttonStyle(tb.done ? AnyButtonStyle(GhostButton()) : AnyButtonStyle(PrimaryButton()))
                }
            }
            .card()
        } else {
            Text("No boosters yet — add one in the Boosters tab to get a daily pick.")
                .font(.subheadline).foregroundStyle(Palette.textSoft)
        }
    }

    // MARK: Today's logs

    @ViewBuilder private var todaySection: some View {
        Text("TODAY").sectionTitle()
        if state.todaysLogs.isEmpty {
            Text("No logs yet today. Tap an emoji above.")
                .font(.subheadline).foregroundStyle(Palette.textSoft)
        } else {
            ForEach(state.todaysLogs) { log in
                HStack(spacing: 10) {
                    Text(log.emoji).font(.title3)
                    Text(Analytics.timeLabel(log.ts)).foregroundStyle(Palette.textSoft)
                    if let note = log.note {
                        Text("“\(note)”").italic().lineLimit(1)
                    }
                    Spacer()
                    Button {
                        state.deleteLog(log.id)
                    } label: { Image(systemName: "xmark").font(.caption) }
                    .tint(Palette.textSoft)
                }
                .font(.subheadline)
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: Note sheet

    private func noteSheet(for emoji: Emoji) -> some View {
        VStack(spacing: 16) {
            Text(emoji.emoji).font(.system(size: 56))
            Text(emoji.label).font(.headline)
            TextField("Add a note (optional)…", text: $note)
                .inputField()
            HStack {
                Button("Skip") { commit(emoji, note: nil) }
                    .buttonStyle(GhostButton())
                Button("Save log") { commit(emoji, note: note) }
                    .buttonStyle(PrimaryButton())
            }
        }
        .padding(24)
        .presentationDetents([.height(280)])
    }

    private func commit(_ emoji: Emoji, note: String?) {
        state.log(emoji, note: note)
        pendingEmoji = nil
    }
}

extension Text {
    func sectionTitle() -> some View {
        self.font(.caption.weight(.semibold))
            .tracking(1)
            .foregroundStyle(Palette.textSoft)
            .padding(.top, 12)
    }
}

/// Type-erased ButtonStyle so the "done" button can swap styles inline.
struct AnyButtonStyle: ButtonStyle {
    private let makeBodyClosure: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) {
        makeBodyClosure = { config in AnyView(style.makeBody(configuration: config)) }
    }
    func makeBody(configuration: Configuration) -> some View { makeBodyClosure(configuration) }
}
