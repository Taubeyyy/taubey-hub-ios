import SwiftUI
import PhotosUI
import UIKit

/// A character's picture, for the ones the wiki has none of. Delta refuses
/// every screenshot from a script, so the picture is taken on the phone:
/// "Ins Bild holen" has the script show the character big on a dark card in
/// a bright green screen (char.stage), you take a screenshot of the game and
/// pick it here - the card is found by its green frame and cut out - or any
/// screenshot, and the square is moved by hand. Stored on the server: every
/// dashboard and app then shows it.
struct PictureSheet: View {
    let name: String
    let rarity: String
    let game: String
    let onChange: () -> Void

    init(name: String, rarity: String, game: String, onChange: @escaping () -> Void) {
        self.name = name
        self.rarity = rarity
        self.game = game
        self.onChange = onChange
    }

    init(item: Item, game: String, onChange: @escaping () -> Void) {
        self.init(name: item.name, rarity: item.rarity, game: game, onChange: onChange)
    }

    @EnvironmentObject var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var pick: PhotosPickerItem?
    @State private var picked: UIImage?
    @State private var crop: CGRect = .zero
    @State private var found = false
    @State private var busy = false

    /// any instance of the game will do: the model is in the game's files
    private var agent: Agent? { (store.overview?.agents ?? []).first { $0.online && $0.game == game } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    preview
                        .frame(width: 150, height: 150)
                        .background(Theme.raised)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Theme.gradient(rarity: rarity), lineWidth: 2))
                        .shadow(color: Theme.color(rarity: rarity).opacity(0.35), radius: 10, y: 2)
                        .padding(.top, 8)

                    VStack(spacing: 4) {
                        Text(name).font(.system(size: 20, weight: .bold)).foregroundColor(Theme.text)
                        if !rarity.isEmpty { RarityText(name: rarity, size: 14) }
                    }

                    step(1, "Ins Bild holen",
                         agent.map { "\($0.account) zeigt \(name) 20 s lang groß auf grünem Grund – mach in der Zeit einen Screenshot vom Spiel." }
                            ?? "Keine Instanz online – nimm einen Screenshot, auf dem das Spiel die Figur zeigt.") {
                        Button {
                            guard let id = agent?.id else { return }
                            Haptics.tap()
                            Task { _ = await store.run("char.stage", args: ["name": .string(name), "seconds": .number(20)], agent: id, patience: 5) }
                        } label: {
                            Label("Ins Bild holen", systemImage: "sparkles.rectangle.stack").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(agent == nil)
                    }

                    step(2, "Screenshot wählen", "Die App findet die Karte am grünen Rand von selbst.") {
                        PhotosPicker(selection: $pick, matching: .images) {
                            Label(picked == nil ? "Aus Fotos wählen" : "Anderen wählen", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line2, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Theme.text)
                    }

                    if let picked = picked {
                        step(3, found ? "Karte gefunden" : "Ausschnitt wählen",
                             found ? "Passt es nicht ganz: ziehen verschiebt, mit zwei Fingern größer oder kleiner."
                                   : "Kein grüner Rand im Bild – zieh das Quadrat auf die Figur, mit zwei Fingern größer oder kleiner.") {
                            CropBox(image: picked, crop: $crop)
                                .frame(height: 330)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button {
                            Task { await upload() }
                        } label: {
                            HStack {
                                if busy { ProgressView().tint(.white) } else { Text("Für alle speichern") }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(busy || crop.width < 16)
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
                    guard let data = try? await newPick.loadTransferable(type: Data.self),
                          let raw = UIImage(data: data) else { return }
                    let image = PictureSheet.upright(raw)
                    let card = image.cgImage.flatMap { StageFinder.card(in: $0) }
                    picked = image
                    found = card != nil
                    crop = card ?? PictureSheet.middleSquare(of: image)
                    if card != nil { Haptics.success() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// what will be stored: the chosen square while there is one, else the picture now
    @ViewBuilder private var preview: some View {
        if let picked = picked, let cut = PictureSheet.cut(picked, crop) {
            Image(uiImage: cut).resizable().scaledToFill()
        } else {
            AsyncImage(url: HubAPI.imageURL(game: game, name: name)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.square").font(.system(size: 46)).foregroundColor(Theme.faint)
                }
            }
        }
    }

    private func step<Content: View>(_ n: Int, _ title: String, _ hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Text("\(n)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.accent))
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
            }
            content()
            Text(hint).font(.system(size: 12.5)).foregroundColor(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    @MainActor
    private func upload() async {
        guard let image = picked, let png = PictureSheet.png(image, crop) else { return }
        busy = true
        let game = self.game, name = self.name
        if await store.call({ try await store.api.uploadPicture(game: game, name: name, png: png) }) != nil {
            store.say("Bild von \(name) gespeichert")
            Haptics.success()
            onChange()
            dismiss()
        }
        busy = false
    }

    @MainActor
    private func remove() async {
        busy = true
        let game = self.game, name = self.name
        if await store.call({ try await store.api.removePicture(game: game, name: name) }) != nil {
            store.say("Eigenes Bild entfernt")
            onChange()
            dismiss()
        }
        busy = false
    }

    // MARK: pixels

    /// Photos can come turned (the orientation is only a flag): drawn once
    /// upright, so the picture's pixels and what is shown agree.
    static func upright(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up, image.cgImage != nil { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func pixelSize(_ image: UIImage) -> CGSize {
        guard let cg = image.cgImage else { return .zero }
        return CGSize(width: cg.width, height: cg.height)
    }

    static func middleSquare(of image: UIImage) -> CGRect {
        let size = pixelSize(image)
        let side = min(size.width, size.height) * 0.6
        return CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side).integral
    }

    static func cut(_ image: UIImage, _ rect: CGRect) -> UIImage? {
        guard rect.width >= 4, let cg = image.cgImage?.cropping(to: rect.integral) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// The square, 256 px, as PNG - small enough for the server's limit.
    static func png(_ image: UIImage, _ rect: CGRect, side: CGFloat = 256) -> Data? {
        guard let cut = cut(image, rect) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            cut.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }.pngData()
    }
}

/// The picture with a square on it: dragging moves the square, two fingers
/// make it bigger or smaller. `crop` is in the picture's pixels.
struct CropBox: View {
    let image: UIImage
    @Binding var crop: CGRect
    @State private var dragFrom: CGRect?
    @State private var zoomFrom: CGRect?

    var body: some View {
        GeometryReader { geo in
            let size = PictureSheet.pixelSize(image)
            let scale = size.width > 0 ? min(geo.size.width / size.width, geo.size.height / size.height) : 1
            let shown = CGSize(width: size.width * scale, height: size.height * scale)
            let origin = CGPoint(x: (geo.size.width - shown.width) / 2, y: (geo.size.height - shown.height) / 2)
            let box = CGRect(x: origin.x + crop.minX * scale, y: origin.y + crop.minY * scale,
                             width: crop.width * scale, height: crop.height * scale)
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.35)
                Image(uiImage: image)
                    .resizable()
                    .frame(width: shown.width, height: shown.height)
                    .offset(x: origin.x, y: origin.y)
                Path { p in
                    p.addRect(CGRect(origin: origin, size: shown))
                    p.addRect(box)
                }
                .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Theme.accent2, lineWidth: 2)
                    .frame(width: box.width, height: box.height)
                    .offset(x: box.minX, y: box.minY)
                    .shadow(color: Theme.accent.opacity(0.6), radius: 6)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { v in
                        let from = dragFrom ?? crop
                        if dragFrom == nil { dragFrom = crop }
                        crop = CropBox.fit(from.offsetBy(dx: v.translation.width / scale, dy: v.translation.height / scale), in: size)
                    }
                    .onEnded { _ in dragFrom = nil }
                    .simultaneously(with:
                        MagnificationGesture()
                            .onChanged { m in
                                let from = zoomFrom ?? crop
                                if zoomFrom == nil { zoomFrom = crop }
                                let side = max(24, min(min(size.width, size.height), from.width * m))
                                crop = CropBox.fit(CGRect(x: from.midX - side / 2, y: from.midY - side / 2, width: side, height: side), in: size)
                            }
                            .onEnded { _ in zoomFrom = nil }
                    )
            )
        }
    }

    /// kept square and inside the picture
    static func fit(_ r: CGRect, in size: CGSize) -> CGRect {
        let side = min(r.width, size.width, size.height)
        let x = min(max(0, r.minX), size.width - side)
        let y = min(max(0, r.minY), size.height - side)
        return CGRect(x: x, y: y, width: side, height: side)
    }
}
