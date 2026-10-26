import Foundation

// Ported from src/lib/format.ts.
enum Formatters {
    static func cents(_ cents: Int?) -> String {
        guard let cents else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "—"
    }

    /// Lenient parse for Postgres `timestamptz` (with/without fractional seconds)
    /// and plain `date` columns like `lease_start`.
    static func parseISODate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: s) { return d }

        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = TimeZone(identifier: "UTC")
        return dateOnly.date(from: s)
    }

    static func date(_ s: String?) -> String {
        guard let d = parseISODate(s) else { return "—" }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.locale = Locale(identifier: "en_US")
        return df.string(from: d)
    }

    static func date(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = Locale(identifier: "en_US")
        return df.string(from: d)
    }

    static func dateTime(_ s: String?) -> String {
        guard let d = parseISODate(s) else { return "—" }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = Locale(identifier: "en_US")
        return df.string(from: d)
    }

    static func truncateHash(_ hash: String, chars: Int = 10) -> String {
        guard hash.count > chars * 2 else { return hash }
        return "\(hash.prefix(chars))\u{2026}\(hash.suffix(chars))"
    }

    static func propertyDisplayName(_ p: Property) -> String {
        p.nickname?.isEmpty == false ? p.nickname! : (p.address_line1?.isEmpty == false ? p.address_line1! : "Untitled property")
    }

    static func isoTimestamp(_ date: Date = Date()) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}
