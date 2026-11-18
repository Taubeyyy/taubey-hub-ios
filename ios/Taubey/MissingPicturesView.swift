import SwiftUI

/// The characters of your accounts that have no picture anywhere - not in the
/// wiki, not taken before. Tapping one opens the picture sheet: the script
/// puts the character in the picture, you take a screenshot and pick it.
struct MissingPicturesView: View {
    @EnvironmentObject var store: HubStore
    @State private var rows: [MissingPicture] = []
    @State private var loaded = false
    @State private var open: MissingPicture?

    var body: some View {
        List {
            Section {
                if !loaded {
                    ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
                } else if rows.isEmpty {
                    Label("Jeder Charakter hat ein Bild.", systemImage: "checkmark.seal.fill")
                        .foregroundColor(Theme.good)
                }
                ForEach(rows) { row in
                    Button { open = row } label: {
                        HStack(spacing: 12) {
                            Portrait(name: row.name, game: row.game, rarity: row.rarity, size: 46, radius: 12)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.name).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
                                if !row.rarity.isEmpty { RarityText(name: row.rarity, size: 12) }
                            }
                            Spacer()
                            Image(systemName: "camera.viewfinder").foregroundColor(Theme.accent2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Für diese hat weder das Wiki noch das Spiel ein Bild. Antippen: das Script stellt die Figur groß ins Bild, du machst einen Screenshot und wählst ihn aus.")
                    .foregroundColor(Theme.faint)
            }
            .rowSurface()
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Fehlende Bilder")
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $open) { row in
            PictureSheet(name: row.name, rarity: row.rarity, game: row.game) {
                Task { await load() }
            }
        }
    }

    private func load() async {
        if let list = await store.call({ try await store.api.missingPictures() }) {
            rows = list.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        loaded = true
    }
}
