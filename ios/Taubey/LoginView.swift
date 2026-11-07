import SwiftUI

/// Signed in by a code from the web dashboard - the same way the Home Screen
/// web app signs in, because Discord's login would leave the app.
struct LoginView: View {
    @EnvironmentObject var store: HubStore
    @State private var code = ""
    @State private var busy = false
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TAUBEY")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .kerning(4)
                        .foregroundColor(Theme.text)
                    Text("Deine Farm-Instanzen, überall.")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.muted)
                }
                .padding(.top, 40)

                Card(title: "So meldest du dich an", icon: "key.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        step(1, "Am PC **taubey.com/dashboard** öffnen und mit Discord anmelden.")
                        step(2, "Links auf **Alerts**, dann bei *Sign in a phone* auf **Get a code for my phone**.")
                        step(3, "Den Code hier eingeben. Er gilt zehn Minuten, die Anmeldung danach 90 Tage.")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField("", text: $code, prompt: Text("CODE").foregroundColor(Theme.muted.opacity(0.6)))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .focused($focused)
                        .padding(.vertical, 16)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(focused ? Theme.accent : Theme.outline, lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .onSubmit { Task { await submit() } }

                    if let problem = problem { ErrorBanner(text: problem) }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if busy { ProgressView().tint(.white) } else { Text("Anmelden").font(.system(size: 17, weight: .semibold)) }
                            Spacer()
                        }
                        .padding(.vertical, 15)
                        .background(cleanCode.count >= 4 ? Theme.accent : Theme.accent.opacity(0.35))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(busy || cleanCode.count < 4)
                }
            }
            .padding(20)
        }
        .screenBackground()
        .onTapGesture { focused = false }
    }

    private var cleanCode: String { code.uppercased().filter { $0.isLetter || $0.isNumber } }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.accent)
                .frame(width: 22, height: 22)
                .background(Theme.accentSoft)
                .clipShape(Circle())
            Text(text).font(.system(size: 15)).foregroundColor(Theme.text)
        }
    }

    private func submit() async {
        guard !busy, cleanCode.count >= 4 else { return }
        busy = true
        problem = nil
        do {
            try await store.signIn(code: cleanCode)
        } catch {
            problem = error.localizedDescription
        }
        busy = false
    }
}
