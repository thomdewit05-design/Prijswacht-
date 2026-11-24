import Foundation

/// Haalt het totaalbedrag en de datum uit de herkende tekst van een bon of
/// bestelbevestiging. Het resultaat is een voorstel: de gebruiker
/// controleert het altijd in het bevestigingsscherm.
public enum ReceiptParser {
    public struct Result: Equatable, Sendable {
        public var totalCents: Cents?
        public var date: Date?
        /// Eerste regel met letters; vaak de naam van de winkel.
        public var shopName: String?
    }

    public static func parse(lines: [String], calendar: Calendar = .current) -> Result {
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return Result(
            totalCents: total(in: cleaned),
            date: date(in: cleaned, calendar: calendar),
            shopName: cleaned.first { line in
                line.filter(\.isLetter).count >= 3 && amounts(in: line).isEmpty
            })
    }

    // MARK: - Bedrag

    private static let totalWords = ["totaal", "te betalen", "total", "totaalbedrag", "eindbedrag", "bedrag"]
    private static let notTotalWords = ["subtotaal", "sub totaal", "subtotal", "btw", "korting", "wisselgeld", "retour", "excl"]

    static func total(in lines: [String]) -> Cents? {
        // Voorkeur: het bedrag op (of direct onder) een regel met "totaal".
        // Staan er meerdere, dan het laatste: dat is na korting en verzending.
        var candidates: [Cents] = []
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            guard totalWords.contains(where: lower.contains),
                  !notTotalWords.contains(where: lower.contains)
            else { continue }
            if let amount = amounts(in: line).last {
                candidates.append(amount)
            } else if index + 1 < lines.count, let amount = amounts(in: lines[index + 1]).last {
                candidates.append(amount)
            }
        }
        if let last = candidates.last { return last }
        // Anders het grootste bedrag op de bon.
        return lines.flatMap(amounts(in:)).max()
    }

    /// Bedragen met twee decimalen, zoals "1.299,00", "38,50" of "38.50".
    static func amounts(in line: String) -> [Cents] {
        matches(#"(?<![\d.,])\d{1,3}(?:[. ]\d{3})*[.,]\d{2}(?![\d])|(?<![\d.,])\d+[.,]\d{2}(?![\d])"#, in: line)
            .compactMap { Euro.parse($0.replacingOccurrences(of: " ", with: "")) }
    }

    // MARK: - Datum

    private static let monthNames: [(String, Int)] = [
        ("jan", 1), ("feb", 2), ("mrt", 3), ("maa", 3), ("mar", 3), ("apr", 4), ("mei", 5), ("may", 5),
        ("jun", 6), ("jul", 7), ("aug", 8), ("sep", 9), ("okt", 10), ("oct", 10), ("nov", 11), ("dec", 12),
    ]

    static func date(in lines: [String], calendar: Calendar) -> Date? {
        for line in lines {
            let lower = line.lowercased()
            // 2026-11-24
            if let match = groups(#"(?<!\d)(20\d{2})-(\d{1,2})-(\d{1,2})(?!\d)"#, in: lower),
               let date = make(year: match[0], month: match[1], day: match[2], calendar: calendar) {
                return date
            }
            // 24-11-2026, 24/11/26, 24.11.2026
            if let match = groups(#"(?<!\d)(\d{1,2})[-/.](\d{1,2})[-/.](20\d{2}|\d{2})(?!\d)"#, in: lower),
               let date = make(year: match[2], month: match[1], day: match[0], calendar: calendar) {
                return date
            }
            // 24 nov 2026, 24 november 2026
            if let match = textGroups(#"(?<!\d)(\d{1,2}) ([a-z]{3})[a-z]*\.? (20\d{2})(?!\d)"#, in: lower),
               let month = monthNames.first(where: { $0.0 == match[1] })?.1,
               let day = Int(match[0]), let year = Int(match[2]),
               let date = make(year: year, month: month, day: day, calendar: calendar) {
                return date
            }
        }
        return nil
    }

    private static func make(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        let fullYear = year < 100 ? 2000 + year : year
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        let parts = DateComponents(year: fullYear, month: month, day: day, hour: 12)
        guard let date = calendar.date(from: parts),
              calendar.component(.day, from: date) == day
        else { return nil }
        return date
    }

    // MARK: - Reguliere expressies

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    private static func textGroups(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
    }

    private static func groups(_ pattern: String, in text: String) -> [Int]? {
        guard let found = textGroups(pattern, in: text) else { return nil }
        let numbers = found.compactMap(Int.init)
        return numbers.count == found.count ? numbers : nil
    }
}
