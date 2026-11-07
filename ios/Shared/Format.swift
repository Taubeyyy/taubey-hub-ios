import Foundation

/// Numbers the way the scripts and the web dashboard write them:
/// 1.23K, 12.3M, 123B ... up to Dc. Same rule for the digits - two below 10,
/// one below 100, none above - and trailing zeros dropped.
enum Format {
    static let suffixes = ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        let sign = value < 0 ? "-" : ""
        var n = abs(value)
        if n < 1000 {
            if n < 10 && n.rounded() != n { return sign + trim(String(format: "%.1f", n)) }
            return sign + String(Int(n.rounded()))
        }
        var step = 0
        while n >= 1000 && step < suffixes.count {
            n /= 1000
            step += 1
        }
        let places = n < 10 ? 2 : (n < 100 ? 1 : 0)
        let text = trim(String(format: "%.\(places)f", n))
        return sign + text + suffixes[step - 1]
    }

    private static func trim(_ text: String) -> String {
        guard text.contains(".") else { return text }
        var t = text
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return t
    }

    /// 45s, 12m, 3h 20m, 2d 4h.
    static func duration(_ seconds: Double?) -> String {
        guard let s = seconds, s.isFinite else { return "–" }
        if s <= 0 { return "jetzt" }
        let total = Int(s)
        if total < 60 { return "\(total)s" }
        if total < 3600 { return "\(total / 60)m \(total % 60)s" }
        if total < 86400 { return "\(total / 3600)h \((total % 3600) / 60)m" }
        return "\(total / 86400)d \((total % 86400) / 3600)h"
    }

    static func ago(_ date: Date, now: Date = Date()) -> String {
        let s = now.timeIntervalSince(date)
        if s < 60 { return "gerade eben" }
        if s < 3600 { return "vor \(Int(s / 60)) min" }
        if s < 86400 { return "vor \(Int(s / 3600)) h" }
        return "vor \(Int(s / 86400)) T"
    }

    /// A slider value at the slider's own precision.
    static func slider(_ value: Double, rounding: Int) -> String {
        if rounding <= 0 { return String(Int(value.rounded())) }
        return String(format: "%.\(rounding)f", value)
    }

    static func round(_ value: Double, to places: Int) -> Double {
        let f = pow(10.0, Double(max(0, places)))
        return (value * f).rounded() / f
    }
}
