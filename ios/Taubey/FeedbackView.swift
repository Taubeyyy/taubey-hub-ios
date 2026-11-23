import SwiftUI

/// "Feedback an Claude": what bothers or is missing, written down while using
/// the app. It lands in the Claude app under the project Taubey; picking it
/// there (or "Mach die Updates") lets Claude on the server build it, and the
/// new version shows up here as an update.
struct FeedbackView: View {
    @EnvironmentObject var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var screen = "Allgemein"
    @State private var sending = false
    @FocusState private var focused: Bool

    private let screens = ["Allgemein", "Übersicht", "Instanzen", "Stände & Jobs", "Inventar", "Events", "Konto", "Einstellungen", "Script"]

    var body: some View {
        List {
            Section {
                TextEditor(text: $text)
                    .focused($focused)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(Theme.text)
                Picker("Wo?", selection: $screen) {
                    ForEach(screens, id: \.self) { Text($0).tag($0) }
                }
            } header: {
                Text("Was stört, was fehlt?")
            } footer: {
                Text("Landet in deiner Claude-App unter Taubey. Dort antippen oder „Mach die Updates“ – Claude baut es, und die neue Version erscheint hier oben als Update.")
                    .foregroundColor(Theme.faint)
            }
            .rowSurface()

            Section {
                Button {
                    Task { await send() }
                } label: {
                    HStack {
                        if sending { ProgressView().tint(.white) } else { Label("An Claude schicken", systemImage: "paperplane.fill") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .barRoom()
        .navigationTitle("Feedback an Claude")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
    }

    private func send() async {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard note.count >= 3 else { return }
        sending = true
        defer { sending = false }
        let where_ = screen
        if await store.call({ try await store.api.sendFeedback(note, screen: where_) }) != nil {
            Haptics.success()
            store.say("Bei Claude angekommen – in der Claude-App unter Taubey")
            text = ""
            dismiss()
        } else {
            // the note stays in the box, nothing is lost
            Haptics.failure()
            store.say("Nicht angekommen – " + (store.error ?? "keine Verbindung, nochmal versuchen"))
        }
    }
}
