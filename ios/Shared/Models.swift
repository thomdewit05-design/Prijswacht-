import Foundation
import PrijswachtCore
import SwiftData

/// Een aankoop die de app bewaakt. Bedragen in gehele centen.
@Model
final class Purchase {
    @Attribute(.unique) var id: UUID
    var title: String
    var imageURLString: String?
    var productURLString: String?
    var ean: String?
    var shopID: String
    var shopName: String
    var orderNumber: String?
    var paidCents: Int
    var purchaseDate: Date
    var deliveryDate: Date?
    /// Laatste dag waarop retourneren nog kan.
    var returnLastDay: Date
    var createdAt: Date

    // Prijsbewaking
    var currentCents: Int?
    var lastCheckedAt: Date?
    /// Daling die één keer gezien is en op de tweede controle wacht.
    var pendingDropCents: Int?
    var pendingDropSeenAt: Date?
    /// Twee keer bevestigde lagere prijs.
    var confirmedCents: Int?
    var confirmedAt: Date?

    // Afloop
    var refusedRoutesRaw: String
    var reclaimedCents: Int
    var archivedAt: Date?

    init(
        title: String, shop: ShopProfile, paidCents: Int, purchaseDate: Date,
        deliveryDate: Date? = nil, productURL: URL? = nil, imageURL: URL? = nil,
        ean: String? = nil, orderNumber: String? = nil, now: Date = .now
    ) {
        id = UUID()
        self.title = title
        imageURLString = imageURL?.absoluteString
        productURLString = productURL?.absoluteString
        self.ean = ean
        shopID = shop.id
        shopName = shop.name
        self.orderNumber = orderNumber
        self.paidCents = paidCents
        self.purchaseDate = purchaseDate
        self.deliveryDate = deliveryDate
        returnLastDay = ReturnWindow.lastDay(
            purchaseDate: purchaseDate, deliveryDate: deliveryDate, returnDays: shop.returnDays)
        createdAt = now
        refusedRoutesRaw = ""
        reclaimedCents = 0
    }
}

extension Purchase {
    var productURL: URL? { productURLString.flatMap(URL.init(string:)) }
    var imageURL: URL? { imageURLString.flatMap(URL.init(string:)) }

    var isArchived: Bool { archivedAt != nil }

    func daysRemaining(now: Date = .now) -> Int {
        ReturnWindow.daysRemaining(lastDay: returnLastDay, now: now)
    }

    /// Telt mee voor de grens van de gratis versie.
    func isRunning(now: Date = .now) -> Bool {
        !isArchived && daysRemaining(now: now) >= 0
    }

    /// Bevestigde daling in centen; 0 als er geen is.
    var dropCents: Int {
        guard let confirmedCents else { return 0 }
        return max(paidCents - confirmedCents, 0)
    }

    var pendingDrop: PendingDrop? {
        get {
            guard let pendingDropCents, let pendingDropSeenAt else { return nil }
            return PendingDrop(priceCents: pendingDropCents, firstSeenAt: pendingDropSeenAt)
        }
        set {
            pendingDropCents = newValue?.priceCents
            pendingDropSeenAt = newValue?.firstSeenAt
        }
    }

    var refusedRoutes: Set<Route> {
        get { Set(refusedRoutesRaw.split(separator: ",").compactMap { Route(rawValue: String($0)) }) }
        set { refusedRoutesRaw = newValue.map(\.rawValue).sorted().joined(separator: ",") }
    }
}

/// Wat er met een route gebeurde: Gelukt of Geweigerd. Voedt de teller en
/// het slagingspercentage per winkel.
@Model
final class Outcome {
    var id: UUID
    var purchaseID: UUID
    var purchaseTitle: String
    var shopID: String
    var shopName: String
    var routeRaw: String
    var succeeded: Bool
    var amountCents: Int
    var date: Date

    init(purchase: Purchase, route: Route, succeeded: Bool, amountCents: Int, date: Date = .now) {
        id = UUID()
        purchaseID = purchase.id
        purchaseTitle = purchase.title
        shopID = purchase.shopID
        shopName = purchase.shopName
        routeRaw = route.rawValue
        self.succeeded = succeeded
        self.amountCents = amountCents
        self.date = date
    }

    var route: Route? { Route(rawValue: routeRaw) }
}
