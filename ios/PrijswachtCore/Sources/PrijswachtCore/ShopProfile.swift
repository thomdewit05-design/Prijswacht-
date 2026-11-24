import Foundation

/// Winkelprofiel: wat de app over een winkel moet weten voor de aftelling en
/// het advies. De waarden komen uit de voorwaarden van de winkel en worden
/// door een mens ingevuld; `verified` zegt of dat al gebeurd is.
public struct ShopProfile: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// Hostnamen zonder "www.", bijvoorbeeld "bol.com".
    public var domains: [String]
    public var country: String
    public var returnDays: Int
    /// nil = onbekend. De app rekent dan geen netto bedrag uit voor route 2.
    public var returnCostCents: Cents?
    public var contactURL: URL?
    public var contactEmail: String?
    public var priceGuarantee: Bool
    public var verified: Bool

    public init(
        id: String, name: String, domains: [String], country: String = "NL",
        returnDays: Int = ShopProfile.legalCoolingOffDays, returnCostCents: Cents? = nil,
        contactURL: URL? = nil, contactEmail: String? = nil,
        priceGuarantee: Bool = false, verified: Bool = false
    ) {
        self.id = id
        self.name = name
        self.domains = domains
        self.country = country
        self.returnDays = returnDays
        self.returnCostCents = returnCostCents
        self.contactURL = contactURL
        self.contactEmail = contactEmail
        self.priceGuarantee = priceGuarantee
        self.verified = verified
    }

    /// Wettelijke bedenktijd bij online aankopen in de EU.
    public static let legalCoolingOffDays = 14

    /// Profiel voor een winkel die we niet kennen: alleen de wettelijke
    /// bedenktijd, de rest onbekend.
    public static func unknown(host: String) -> ShopProfile {
        let clean = ShopDirectory.normalize(host: host)
        return ShopProfile(id: clean, name: clean, domains: [clean])
    }
}

public struct ShopDirectory: Sendable {
    public let shops: [ShopProfile]

    public init(shops: [ShopProfile]) {
        self.shops = shops
    }

    public init(jsonData: Data) throws {
        shops = try JSONDecoder().decode([ShopProfile].self, from: jsonData)
    }

    public func shop(id: String) -> ShopProfile? {
        shops.first { $0.id == id }
    }

    /// Zoekt op hostnaam, inclusief subdomeinen ("m.bol.com" -> bol.com).
    public func shop(for url: URL) -> ShopProfile? {
        guard let host = url.host else { return nil }
        let clean = Self.normalize(host: host)
        return shops.first { shop in
            shop.domains.contains { clean == $0 || clean.hasSuffix("." + $0) }
        }
    }

    public func shopOrUnknown(for url: URL) -> ShopProfile {
        shop(for: url) ?? .unknown(host: url.host ?? "onbekend")
    }

    public static func normalize(host: String) -> String {
        let lower = host.lowercased()
        return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
    }
}
