import Foundation

/// De drie routes naar geld terug.
public enum Route: String, Codable, CaseIterable, Sendable {
    /// 1. Vraag de winkel om het verschil.
    case askDifference
    /// 2. Retourneer en bestel opnieuw.
    case returnAndReorder
    /// 3. Claim de laagsteprijsgarantie.
    case priceGuarantee
}

public struct RouteOption: Equatable, Sendable {
    public let route: Route
    /// Prijsverschil zonder kosten.
    public let grossCents: Cents
    /// Wat je netto overhoudt. nil als de retourkosten onbekend zijn.
    public let netCents: Cents?
    /// De app raadt deze route aan (netto boven de drempel, of route 1/3).
    public let recommended: Bool

    public init(route: Route, grossCents: Cents, netCents: Cents?, recommended: Bool) {
        self.route = route
        self.grossCents = grossCents
        self.netCents = netCents
        self.recommended = recommended
    }
}

public struct RouteInput: Sendable {
    public var paidCents: Cents
    /// Huidige prijs bij de winkel waar je kocht.
    public var sameShopCents: Cents?
    /// Laagste prijs bij een andere winkel (voor route 3).
    public var otherShopCents: Cents?
    public var shop: ShopProfile
    public var daysRemaining: Int
    public var thresholdCents: Cents
    /// Routes die de winkel bij deze aankoop al geweigerd heeft.
    public var refused: Set<Route>

    public init(
        paidCents: Cents, sameShopCents: Cents?, otherShopCents: Cents? = nil,
        shop: ShopProfile, daysRemaining: Int, thresholdCents: Cents,
        refused: Set<Route> = []
    ) {
        self.paidCents = paidCents
        self.sameShopCents = sameShopCents
        self.otherShopCents = otherShopCents
        self.shop = shop
        self.daysRemaining = daysRemaining
        self.thresholdCents = thresholdCents
        self.refused = refused
    }
}

public enum RouteAdvisor {
    /// Routes in de volgorde waarin het routescherm ze toont; de eerste is de
    /// aanbevolen route.
    ///
    /// Vaste regel: route 1 staat altijd bovenaan zolang de winkel hem niet
    /// geweigerd heeft. Dat kost de winkel het minst en levert geen extra
    /// pakketten op. Commissie speelt hier bewust geen enkele rol.
    public static func options(for input: RouteInput) -> [RouteOption] {
        var result: [RouteOption] = []
        let windowOpen = input.daysRemaining >= 0
        let sameShopDrop = input.sameShopCents.map { input.paidCents - $0 } ?? 0

        if sameShopDrop > 0, !input.refused.contains(.askDifference) {
            result.append(RouteOption(
                route: .askDifference, grossCents: sameShopDrop,
                netCents: sameShopDrop, recommended: true))
        }

        if let other = input.otherShopCents, input.shop.priceGuarantee,
           !input.refused.contains(.priceGuarantee) {
            let drop = input.paidCents - other
            if drop > 0, drop > sameShopDrop {
                result.append(RouteOption(
                    route: .priceGuarantee, grossCents: drop, netCents: drop, recommended: true))
            }
        }

        if sameShopDrop > 0, windowOpen, !input.refused.contains(.returnAndReorder) {
            let net = input.shop.returnCostCents.map { sameShopDrop - $0 }
            // Alleen aanraden als er netto genoeg overblijft; bij onbekende
            // retourkosten tonen we de route wel, maar raden hem niet aan.
            let recommended = (net ?? 0) >= max(input.thresholdCents, 1)
            result.append(RouteOption(
                route: .returnAndReorder, grossCents: sameShopDrop,
                netCents: net, recommended: recommended))
        }

        return result
    }

    public static func best(for input: RouteInput) -> RouteOption? {
        options(for: input).first
    }
}
