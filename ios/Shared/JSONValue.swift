import Foundation

/// Whatever the hub API sends, without trusting its types. The server is
/// JavaScript: a count can arrive as 3 or "3", a list entry can be broken,
/// and a model that insists on one shape fails silently on the other. So the
/// whole answer is read into this, and the models pick out what they need
/// with forgiving accessors.
enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let d = try? c.decode(Double.self) { self = .number(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let d): try c.encode(d)
        case .bool(let b): try c.encode(b)
        case .object(let o): try c.encode(o)
        case .array(let a): try c.encode(a)
        case .null: try c.encodeNil()
        }
    }

    static func parse(_ data: Data) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: data)
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data("null".utf8)
    }

    subscript(key: String) -> JSONValue {
        if case .object(let o) = self { return o[key] ?? .null }
        return .null
    }

    subscript(index: Int) -> JSONValue {
        if case .array(let a) = self, index >= 0, index < a.count { return a[index] }
        return .null
    }

    var isNull: Bool { if case .null = self { return true }; return false }

    /// A number, also from a numeric string.
    var double: Double? {
        switch self {
        case .number(let d): return d.isFinite ? d : nil
        case .string(let s): return Double(s.trimmingCharacters(in: .whitespaces))
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    var int: Int? {
        guard let d = double, d.isFinite, abs(d) < 9e15 else { return nil }
        return Int(d)
    }

    /// Text, also from a number or a bool - an id can be either.
    var string: String? {
        switch self {
        case .string(let s): return s
        case .number(let d):
            if d.rounded() == d && abs(d) < 9e15 { return String(Int(d)) }
            return String(d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    var bool: Bool? {
        switch self {
        case .bool(let b): return b
        case .number(let d): return d != 0
        case .string(let s):
            switch s.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        default: return nil
        }
    }

    var object: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// A list; an empty JS object `{}` (which Lua's JSON writes for an empty
    /// table) counts as an empty list too.
    var array: [JSONValue]? {
        if case .array(let a) = self { return a }
        if case .object(let o) = self, o.isEmpty { return [] }
        return nil
    }

    var strings: [String] { (array ?? []).compactMap { $0.string } }

    /// A multi-select value is `{label: true}`; Lua writes an empty one as `[]`.
    var selection: Set<String> {
        if let o = object { return Set(o.compactMap { $0.value.bool == true ? $0.key : nil }) }
        return Set(strings)
    }
}
