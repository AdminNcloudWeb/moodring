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
        .onChange(of: scenePhase) { oldPhase, phase in
            switch phase {
            case .active:
                state.reconcileFromSharedStore()
                // Only re-prompt on a genuine reopen (background → active), not
                // the inactive ↔ active flicker the biometric sheet produces.
                if oldPhase == .background { state.requestUnlockIfNeeded() }
            case .background:
                state.lockOnBackground()
            default:
                break
            }
        }
    }
}
