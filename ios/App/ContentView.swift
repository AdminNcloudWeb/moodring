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
        }
        // Auth is required when there's no session (matches the web app, which
        // removed the "continue without an account" option).
        .fullScreenCover(isPresented: .constant(state.auth == .signedOut)) {
            AuthView()
                .environmentObject(state)
        }
    }
}
