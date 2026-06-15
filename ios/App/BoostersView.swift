import SwiftUI

struct BoostersView: View {
    @EnvironmentObject var state: AppState
    @State private var newBooster = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    suggestions
                    Text("YOUR BOOSTERS").sectionTitle()
                    HStack {
                        TextField("Add your own… e.g. go for a walk", text: $newBooster)
                            .inputField()
                        Button("Add") {
                            state.addBooster(newBooster); newBooster = ""
                        }
                        .buttonStyle(PrimaryButton())
                    }
                    boosterList
                }
                .padding(16)
            }
            .background(Palette.bg)
            .navigationTitle("Boosters")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private var suggestions: some View {
        let items = state.activeSuggestions
        if !items.isEmpty {
            Text("SUGGESTIONS").sectionTitle()
            ForEach(items) { s in
                VStack(alignment: .leading, spacing: 12) {
                    Text(s.text).font(.subheadline)
                    HStack {
                        Button("Save to my list") { state.saveSuggestion(s) }
                            .buttonStyle(PrimaryButton())
                        Button("Dismiss") { state.dismissSuggestion(s) }
                            .buttonStyle(GhostButton())
                    }
                }
                .card()
            }
        }
    }

    @ViewBuilder private var boosterList: some View {
        if state.data.boosters.isEmpty {
            Text("No boosters yet. Add one above.")
                .font(.subheadline).foregroundStyle(Palette.textSoft)
        } else {
            ForEach(state.data.boosters) { b in
                HStack {
                    Text(b.text)
                    Spacer()
                    Button {
                        state.removeBooster(b.id)
                    } label: { Image(systemName: "xmark").font(.caption) }
                    .tint(Palette.textSoft)
                }
                .padding(.vertical, 10).padding(.horizontal, 14)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
