import SwiftUI
import PhotosUI
import UIKit

/// A character's picture, for the ones the wiki has none of: pick a
/// screenshot from Photos, it is cut to a square around the middle, made
/// small, and stored on the server - every dashboard and app then shows it.
struct PictureSheet: View {
    let item: Item
    let game: String
    let onChange: () -> Void

    @EnvironmentObject var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var pick: PhotosPickerItem?
    @State private var picked: UIImage?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Group {
                        if let picked = picked {
                            Image(uiImage: picked).resizable().scaledToFill()
                        } else {
                            AsyncImage(url: HubAPI.imageURL(game: game, name: item.name)) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Image(systemName: "person.crop.square").font(.system(size: 50)).foregroundColor(Theme.faint)
                                }
                            }
                        }
                    }
                    .frame(width: 160, height: 160)
                    .background(Theme.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.color(rarity: item.rarity).opacity(0.7), lineWidth: 2))
                    .padding(.top, 10)

                    VStack(spacing: 4) {
                        Text(item.name).font(.system(size: 20, weight: .bold)).foregroundColor(Theme.text)
                        RarityText(name: item.rarity, size: 14)
                    }

                    Text("Das Wiki hat nicht für jeden Charakter ein Bild. Mach im Spiel einen Screenshot, schneide ihn in Fotos grob auf den Kopf zu und wähle ihn hier – er wird quadratisch aus der Mitte genommen.")
                        .font(.system(size: 13.5)).foregroundColor(Theme.muted).multilineTextAlignment(.center)

                    PhotosPicker(selection: $pick, matching: .images) {
                        Label(picked == nil ? "Bild aus Fotos wählen" : "Anderes Bild wählen", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line2, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Theme.text)

                    if picked != nil {
                        Button {
                            Task { await upload() }
                        } label: {
                            HStack {
                                if busy { ProgressView().tint(.white) } else { Text("Für alle speichern") }
                            }
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(busy)
                    }

                    Button(role: .destructive) {
                        Task { await remove() }
                    } label: {
                        Text("Eigenes Bild entfernen").font(.system(size: 14))
                    }
                    .foregroundColor(Theme.bad)
                    .disabled(busy)
                }
                .padding(20)
            }
            .screenBackground()
            .navigationTitle("Bild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Fertig") { dismiss() } }
            }
            .onChange(of: pick) { newPick in
                guard let newPick = newPick else { return }
                Task {
                    if let data = try? await newPick.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        picked = image
                    }
                }
            }
        }
    }

    @MainActor
    private func upload() async {
        guard let image = picked, let png = PictureSheet.square(image) else { return }
        busy = true
        let game = self.game, name = item.name
        if await store.call({ try await store.api.uploadPicture(game: game, name: name, png: png) }) != nil {
            store.say("Bild gespeichert")
            onChange()
            dismiss()
        }
        busy = false
    }

    @MainActor
    private func remove() async {
        busy = true
        let game = self.game, name = item.name
        if await store.call({ try await store.api.removePicture(game: game, name: name) }) != nil {
            store.say("Eigenes Bild entfernt")
            onChange()
            dismiss()
        }
        busy = false
    }

    /// The middle square, 256 px, as PNG - small enough for the server's limit.
    static func square(_ image: UIImage, side: CGFloat = 256) -> Data? {
        let w = image.size.width, h = image.size.height
        let s = min(w, h)
        guard s > 0 else { return nil }
        let scale = side / s
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let out = renderer.image { _ in
            image.draw(in: CGRect(x: -(w - s) / 2 * scale, y: -(h - s) / 2 * scale, width: w * scale, height: h * scale))
        }
        return out.pngData()
    }
}
