import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            TabView {
                LogView()
                    .tabItem { Label("Log", systemImage: "face.smiling") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "chart.line.uptrend.xyaxis") }
                BoostersView()
                    .tabItem { Label("Boosters", systemImage: "sparkles") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }

            // App lock: cover everything until unlocked with Face ID / Touch ID
            // / passcode. Shown while signed in, and pre-emptively before the
            // session resolves at launch (auth == .unknown) so a locked app
            // never flashes content. The signed-out case is handled by AuthView.
            if state.locked && state.auth != .signedOut {
                LockView()
                    .environmentObject(state)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.locked)
        // Auth is required when there's no session (matches the web app, which
        // removed the "continue without an account" option).
        .fullScreenCover(isPresented: .constant(state.auth == .signedOut)) {
            AuthView()
                .environmentObject(state)
        }
    }
}
