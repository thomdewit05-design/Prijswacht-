import Foundation

/// Kant-en-klare berichten voor de winkel. De gebruiker verstuurt ze zelf.
/// Bewust in het Nederlands: het is de taal van de winkel, niet van de app.
public enum MessageComposer {
    public struct Context: Sendable {
        public var productTitle: String
        public var shopName: String
        public var orderNumber: String?
        public var purchaseDate: Date
        public var paidCents: Cents
        public var newCents: Cents
        public var productURL: URL?
        /// Voor route 3: de winkel waar het goedkoper is.
        public var otherShopName: String?
        public var observedAt: Date

        public init(
            productTitle: String, shopName: String, orderNumber: String? = nil,
            purchaseDate: Date, paidCents: Cents, newCents: Cents,
            productURL: URL? = nil, otherShopName: String? = nil, observedAt: Date
        ) {
            self.productTitle = productTitle
            self.shopName = shopName
            self.orderNumber = orderNumber
            self.purchaseDate = purchaseDate
            self.paidCents = paidCents
            self.newCents = newCents
            self.productURL = productURL
            self.otherShopName = otherShopName
            self.observedAt = observedAt
        }
    }

    public struct Message: Equatable, Sendable, Identifiable {
        public var subject: String
        public var body: String
        public var id: String { subject }
    }

    public static func message(for route: Route, context c: Context, calendar: Calendar = .current) -> Message {
        var message = draft(for: route, context: c, calendar: calendar)
        // Lege regels (geen bestelnummer of link) laten geen gat achter.
        while message.body.contains("\n\n\n") {
            message.body = message.body.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return message
    }

    static func draft(for route: Route, context c: Context, calendar: Calendar) -> Message {
        let order = c.orderNumber.flatMap { $0.isEmpty ? nil : $0 }
        let orderLine = order.map { "Bestelnummer: \($0)\n" } ?? ""
        let subjectSuffix = order.map { " (bestelling \($0))" } ?? ""
        let bought = dateText(c.purchaseDate, calendar: calendar)
        let seen = dateText(c.observedAt, calendar: calendar)
        let difference = Euro.string(c.paidCents - c.newCents)
        let link = c.productURL.map { "Productpagina: \($0.absoluteString)\n" } ?? ""

        switch route {
        case .askDifference:
            return Message(
                subject: "Vraag over prijsverschil\(subjectSuffix)",
                body: """
                Beste klantenservice,

                Op \(bought) heb ik bij jullie de \(c.productTitle) gekocht voor \(Euro.string(c.paidCents)). \
                Vandaag (\(seen)) zie ik hetzelfde product bij jullie voor \(Euro.string(c.newCents)), \
                een verschil van \(difference).

                \(orderLine)\(link)
                Zouden jullie het verschil van \(difference) willen terugbetalen? Dat scheelt ons \
                allebei een retour: anders stuur ik het product binnen de bedenktijd terug en \
                bestel ik het opnieuw.

                Alvast bedankt voor het meedenken.

                Met vriendelijke groet,
                """)
        case .returnAndReorder:
            return Message(
                subject: "Herroeping van mijn aankoop\(subjectSuffix)",
                body: """
                Beste klantenservice,

                Hierbij laat ik weten dat ik mijn aankoop van de \(c.productTitle), gekocht op \
                \(bought) voor \(Euro.string(c.paidCents)), binnen de bedenktijd wil herroepen.

                \(orderLine)
                Graag ontvang ik de instructies voor het terugsturen en een bevestiging van \
                deze herroeping.

                Met vriendelijke groet,
                """)
        case .priceGuarantee:
            let other = c.otherShopName ?? "een andere winkel"
            return Message(
                subject: "Beroep op laagsteprijsgarantie\(subjectSuffix)",
                body: """
                Beste klantenservice,

                Op \(bought) heb ik bij jullie de \(c.productTitle) gekocht voor \(Euro.string(c.paidCents)). \
                Bij \(other) is hetzelfde product nu \(Euro.string(c.newCents)) (gezien op \(seen)).

                \(orderLine)\(link)
                Graag doe ik een beroep op jullie laagsteprijsgarantie voor het verschil van \
                \(difference). Laat het me weten als jullie nog iets van mij nodig hebben.

                Met vriendelijke groet,
                """)
        }
    }

    static let months = [
        "januari", "februari", "maart", "april", "mei", "juni",
        "juli", "augustus", "september", "oktober", "november", "december",
    ]

    static func dateText(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        let month = months[max(0, min(11, (parts.month ?? 1) - 1))]
        return "\(parts.day ?? 1) \(month) \(parts.year ?? 0)"
    }
}
