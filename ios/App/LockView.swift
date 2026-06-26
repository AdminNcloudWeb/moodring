import SwiftUI

/// Full-screen gate shown over the app when app lock is on and the app is
/// locked. Auto-prompts for Face ID / Touch ID / passcode on appear; offers a
/// retry button, and a sign-out escape hatch if authentication keeps failing.
struct LockView: View {
    @EnvironmentObject var state: AppState
    @State private var showSignOut = false

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🔒").font(.system(size: 52))
                Text("Moodring is locked").font(.title2.bold())
                Text("Unlock to see your moods.")
                    .font(.subheadline).foregroundStyle(Palette.textSoft)
                    .multilineTextAlignment(.center)

                Button(action: unlock) {
                    Text(BiometricAuth.unlockActionLabel).frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButton())
                .padding(.top, 4)

                if showSignOut {
                    Button("Sign out instead") { state.signOut() }
                        .font(.footnote).tint(Palette.textSoft)
                }
            }
            .padding(24)
            .frame(maxWidth: 320)
        }
        .foregroundStyle(Palette.text)
        .task { unlock() }   // auto-prompt as soon as the lock appears
    }

    private func unlock() {
        Task { @MainActor in
            await state.unlock()
            // Still locked after an attempt → surface the sign-out fallback.
            if state.locked { showSignOut = true }
        }
    }
}
