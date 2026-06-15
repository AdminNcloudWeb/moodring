import SwiftUI

@main
struct MoodringApp: App {
    @StateObject private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .tint(Palette.accent)
                .preferredColorScheme(state.preferredColorScheme)
                .onOpenURL { url in
                    Task { await SupabaseService.shared.handle(url: url) }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { state.reconcileFromSharedStore() }
        }
    }
}
