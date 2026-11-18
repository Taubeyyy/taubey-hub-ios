import CoreGraphics

/// The card the script shows for a photo (char.stage): a dark square in the
/// middle of a bright green screen. Its square in the picture's pixels, or
/// nil when the picture has no green screen.
enum StageFinder {
    static func card(in cg: CGImage) -> CGRect? {
        let w = cg.width, h = cg.height
        guard w > 32, h > 32 else { return nil }
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let drawn: Bool = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        func green(_ x: Int, _ y: Int) -> Bool {
            let o = (y * w + x) * 4
            let r = Int(px[o]), g = Int(px[o + 1]), b = Int(px[o + 2])
            return g > 150 && g - max(r, b) > 80
        }
        // how far the green screen reaches
        var minX = w, minY = h, maxX = -1, maxY = -1, count = 0
        let step = max(1, min(w, h) / 300)
        var y = 0
        while y < h {
            var x = 0
            while x < w {
                if green(x, y) {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                    count += 1
                }
                x += step
            }
            y += step
        }
        guard maxX > minX, maxY > minY, count > 300 else { return nil }
        let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
        let expected = Double(min(maxX - minX, maxY - minY)) * 0.7
        // the card's edges: from the middle outwards to the first green
        func run(_ dx: Int, _ dy: Int) -> Int {
            var x = cx, y = cy, n = 0
            while x >= 0, x < w, y >= 0, y < h, !green(x, y) { x += dx; y += dy; n += 1 }
            return n
        }
        let left = run(-1, 0), right = run(1, 0), up = run(0, -1), down = run(0, 1)
        let measured = Double(min(left + right, up + down))
        var rect: CGRect
        if abs(measured - expected) < expected * 0.15 {
            let s = measured
            let midX = Double(cx - left) + Double(left + right) / 2
            let midY = Double(cy - up) + Double(up + down) / 2
            rect = CGRect(x: midX - s / 2, y: midY - s / 2, width: s, height: s)
        } else {
            // something green on the character cut a run short: the card is
            // where the script puts it, 70% of the shorter side, centred
            rect = CGRect(x: Double(cx) - expected / 2, y: Double(cy) - expected / 2, width: expected, height: expected)
        }
        return rect.insetBy(dx: rect.width * 0.015, dy: rect.height * 0.015).integral
    }
}
