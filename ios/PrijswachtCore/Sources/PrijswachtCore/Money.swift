import Foundation

/// Bedragen zijn altijd gehele centen (Int), nooit Double.
public typealias Cents = Int

public enum Euro {
    /// "€38", "€38,50", "€1.299", "-€5".
    public static func string(_ cents: Cents) -> String {
        let sign = cents < 0 ? "-" : ""
        let value = abs(cents)
        let euros = value / 100
        let rest = value % 100

        var digits = String(euros)
        var grouped = ""
        while digits.count > 3 {
            grouped = "." + digits.suffix(3) + grouped
            digits = String(digits.dropLast(3))
        }
        grouped = digits + grouped

        if rest == 0 { return "\(sign)€\(grouped)" }
        let restText = rest < 10 ? "0\(rest)" : "\(rest)"
        return "\(sign)€\(grouped),\(restText)"
    }

    /// Leest bedragen zoals mensen en webwinkels ze schrijven:
    /// "1.299,00", "1299.00", "€ 38,5", "1,299.00", "38". Geeft nil bij onzin.
    public static func parse(_ text: String) -> Cents? {
        let allowed = Set("0123456789.,")
        let cleaned = String(text.filter { allowed.contains($0) })
        guard cleaned.contains(where: \.isNumber) else { return nil }

        // Het laatste scheidingsteken is het decimaalteken als er 1 of 2
        // cijfers achter staan; anders is het een duizendtalscheiding.
        var whole = cleaned
        var fraction = ""
        if let last = cleaned.lastIndex(where: { $0 == "." || $0 == "," }) {
            let tail = cleaned[cleaned.index(after: last)...]
            if tail.count == 1 || tail.count == 2 {
                whole = String(cleaned[..<last])
                fraction = String(tail)
            }
        }
        whole = whole.filter(\.isNumber)
        if fraction.contains(where: { !$0.isNumber }) { return nil }
        if fraction.count == 1 { fraction += "0" }

        guard let euros = Int(whole.isEmpty ? "0" : whole),
              let rest = Int(fraction.isEmpty ? "0" : fraction),
              euros <= 10_000_000
        else { return nil }
        return euros * 100 + rest
    }

    /// Voor JSON-LD, waar een prijs een getal óf een tekst kan zijn.
    public static func parse(json value: Any?) -> Cents? {
        switch value {
        case let text as String:
            return parse(text)
        case let number as NSNumber:
            // Via de tekstvorm, zodat 38.1 niet 3809 wordt door afronding.
            return parse(number.stringValue.replacingOccurrences(of: ",", with: "."))
        default:
            return nil
        }
    }
}
