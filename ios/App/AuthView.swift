import SwiftUI

/// Two-screen auth flow matching the web app: a sign-in screen and a separate
/// create-account screen, plus magic-link. No "continue without an account".
struct AuthView: View {
    @EnvironmentObject var state: AppState
    private enum Panel { case signIn, signUp }
    @State private var panel: Panel = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var message: (text: String, isError: Bool)?
    @State private var busy = false

    // Cycle the logo through the mood spectrum, like the web app.
    private let logoEmojis = ["😭","😔","😟","😐","😌","🙂","💪","😊","😄","🤩"]
    @State private var logoIndex = 0
    private let logoTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                Text(logoEmojis[logoIndex])
                    .font(.system(size: 52))
                    .id(logoIndex)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onReceive(logoTimer) { _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            logoIndex = (logoIndex + 1) % logoEmojis.count
                        }
                    }

                if panel == .signIn { signInPanel } else { signUpPanel }
            }
            .padding(24)
            .frame(maxWidth: 380)
        }
        .foregroundStyle(Palette.text)
    }

    // MARK: Panels

    private var signInPanel: some View {
        VStack(spacing: 12) {
            Text("Welcome back").font(.title2.bold())
            Text("Sign in to sync your moods across devices.")
                .font(.subheadline).foregroundStyle(Palette.textSoft)
                .multilineTextAlignment(.center)

            fields(passwordPrompt: "Password")
            messageView

            primaryButton("Sign in", busyLabel: "Signing in…", action: signIn)
            Button("Email me a magic link instead", action: sendMagic)
                .font(.footnote).tint(Palette.textSoft)

            HStack { line; Text("New to moodring?").font(.caption).foregroundStyle(Palette.textSoft); line }
                .padding(.vertical, 4)

            Button { switchTo(.signUp) } label: {
                Text("Create an account →").frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButton())
        }
    }

    private var signUpPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Button { switchTo(.signIn) } label: { Text("← Back") }
                    .font(.footnote).tint(Palette.textSoft)
                Spacer()
            }
            Text("Create your account").font(.title2.bold())
            Text("Free, and syncs your moods across every device.")
                .font(.subheadline).foregroundStyle(Palette.textSoft)
                .multilineTextAlignment(.center)

            fields(passwordPrompt: "Password (6+ characters)")
            messageView

            primaryButton("Create account", busyLabel: "Creating account…", action: signUp)
            Button("Already have an account? Sign in") { switchTo(.signIn) }
                .font(.footnote).tint(Palette.textSoft)
        }
    }

    // MARK: Pieces

    private func fields(passwordPrompt: String) -> some View {
        VStack(spacing: 10) {
            TextField("you@email.com", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .inputField()
            SecureField(passwordPrompt, text: $password)
                .textContentType(.password)
                .inputField()
        }
    }

    @ViewBuilder private var messageView: some View {
        if let message {
            Text(message.text)
                .font(.footnote)
                .foregroundStyle(message.isError ? Palette.danger : Palette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Palette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func primaryButton(_ title: String, busyLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(busy ? busyLabel : title).frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButton())
        .disabled(busy)
    }

    private var line: some View { Rectangle().fill(Palette.border).frame(height: 1) }

    // MARK: Actions

    private func switchTo(_ p: Panel) {
        withAnimation { panel = p }
        message = nil
    }

    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else { return set("Enter your email and password.", true) }
        run("Signing in…") { try await state.signInProxy(email: email, password: password) }
    }

    private func signUp() {
        guard !email.isEmpty, password.count >= 6 else { return set("Enter an email and a 6+ character password.", true) }
        run("") {
            let immediate = try await state.signUpProxy(email: email, password: password)
            await MainActor.run {
                set(immediate ? "Account created — signing you in…"
                              : "Account created. Check \(email) to confirm, then sign in.", false)
            }
        }
    }

    private func sendMagic() {
        guard !email.isEmpty else { return set("Enter your email first.", true) }
        run("") {
            try await state.magicLinkProxy(email: email)
            await MainActor.run { set("Magic link sent — check \(email).", false) }
        }
    }

    private func run(_ busyLabel: String, _ op: @escaping () async throws -> Void) {
        busy = true; message = nil
        Task {
            do { try await op() }
            catch { await MainActor.run { set(error.localizedDescription, true) } }
            await MainActor.run { busy = false }
        }
    }

    private func set(_ text: String, _ isError: Bool) { message = (text, isError) }
}

// Auth calls are proxied through AppState so the view never touches the client
// directly (keeps the service swappable / testable).
extension AppState {
    func signInProxy(email: String, password: String) async throws {
        try await SupabaseService.shared.signIn(email: email, password: password)
    }
    func signUpProxy(email: String, password: String) async throws -> Bool {
        try await SupabaseService.shared.signUp(email: email, password: password)
    }
    func magicLinkProxy(email: String) async throws {
        try await SupabaseService.shared.sendMagicLink(email: email)
    }
}

// MARK: - Reusable styling

extension View {
    func inputField() -> some View {
        self
            .padding(12)
            .background(Palette.bg)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 11)
            .padding(.horizontal, 18)
            .foregroundStyle(.white)
            .background(Palette.accent.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 11)
            .padding(.horizontal, 18)
            .foregroundStyle(Palette.text)
            .background(Palette.surface2)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
