import Foundation

/// Eén prijsmeting van een productpagina.
public struct Offer: Equatable, Sendable {
    public var ean: String?
    public var title: String?
    public var imageURL: URL?
    public var priceCents: Cents
    public var currency: String
    public var inStock: Bool
    public var isNew: Bool
    public var seller: String?

    public init(
        ean: String? = nil, title: String? = nil, imageURL: URL? = nil,
        priceCents: Cents, currency: String = "EUR", inStock: Bool = true,
        isNew: Bool = true, seller: String? = nil
    ) {
        self.ean = ean
        self.title = title
        self.imageURL = imageURL
        self.priceCents = priceCents
        self.currency = currency
        self.inStock = inStock
        self.isNew = isNew
        self.seller = seller
    }
}

/// Een daling die één keer gezien is en nog op de tweede controle wacht.
public struct PendingDrop: Equatable, Sendable {
    public var priceCents: Cents
    public var firstSeenAt: Date

    public init(priceCents: Cents, firstSeenAt: Date) {
        self.priceCents = priceCents
        self.firstSeenAt = firstSeenAt
    }
}

public enum DropDecision: Equatable, Sendable {
    /// Geen (geldige) daling; een eventuele wachtende daling vervalt.
    case none
    /// Daling gezien, wacht op de tweede controle.
    case pending(PendingDrop)
    /// Twee keer bevestigd: dit mag een melding worden.
    case confirmed(priceCents: Cents, dropCents: Cents)
}

/// Valse meldingen zijn dodelijk. Een prijsdaling wordt pas een melding na
/// een tweede controle, minstens een uur later, en alleen bij: nieuw, zelfde
/// verkoper, op voorraad, in euro's en boven de drempel.
public enum DropDetector {
    public static let minimumConfirmationInterval: TimeInterval = 3600

    public static func evaluate(
        offer: Offer, paidCents: Cents, thresholdCents: Cents,
        expectedSeller: String?, pending: PendingDrop?, now: Date
    ) -> DropDecision {
        guard offer.currency.uppercased() == "EUR", offer.isNew, offer.inStock,
              offer.priceCents > 0,
              sellerMatches(offer.seller, expected: expectedSeller)
        else { return .none }

        let drop = paidCents - offer.priceCents
        guard drop > 0, drop >= thresholdCents else { return .none }

        guard let pending else {
            return .pending(PendingDrop(priceCents: offer.priceCents, firstSeenAt: now))
        }
        guard now.timeIntervalSince(pending.firstSeenAt) >= minimumConfirmationInterval else {
            // Te vroeg voor de tweede controle; bewaar het oudste tijdstip en
            // de hoogste van de twee prijzen.
            return .pending(PendingDrop(
                priceCents: max(pending.priceCents, offer.priceCents),
                firstSeenAt: pending.firstSeenAt))
        }
        // Meld de voorzichtigste daling: de hoogste prijs van beide metingen.
        let price = max(pending.priceCents, offer.priceCents)
        return .confirmed(priceCents: price, dropCents: paidCents - price)
    }

    /// Een onbekende verkoper op de pagina keuren we goed; een andere
    /// verkoper dan de winkel zelf (marktplaats) niet.
    static func sellerMatches(_ seller: String?, expected: String?) -> Bool {
        guard let seller = seller?.normalizedSellerName, !seller.isEmpty,
              let expected = expected?.normalizedSellerName, !expected.isEmpty
        else { return true }
        return seller.contains(expected) || expected.contains(seller)
    }
}

private extension String {
    var normalizedSellerName: String {
        lowercased()
            .replacingOccurrences(of: ".com", with: "")
            .replacingOccurrences(of: ".nl", with: "")
            .filter { $0.isLetter || $0.isNumber }
    }
}
