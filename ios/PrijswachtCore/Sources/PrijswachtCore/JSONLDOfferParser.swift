import Foundation

/// Leest product en prijs uit de gestructureerde gegevens (JSON-LD,
/// schema.org Product/Offer) die webwinkels voor zoekmachines meesturen.
public enum JSONLDOfferParser {
    public enum Failure: Error, Equatable, Sendable {
        case noStructuredData
        case noProduct
        case noOffer
        /// Alleen een "vanaf"-prijs of meerdere aanbieders: geen prijs waar
        /// we een melding op durven baseren.
        case ambiguousPrice
    }

    public static func parse(html: String) -> Result<Offer, Failure> {
        let blocks = jsonBlocks(in: html)
        guard !blocks.isEmpty else { return .failure(.noStructuredData) }

        var products: [[String: Any]] = []
        for block in blocks {
            guard let data = block.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            else { continue }
            collectProducts(in: json, into: &products)
        }
        guard !products.isEmpty else { return .failure(.noProduct) }

        var lastFailure: Failure = .noOffer
        for product in products {
            switch offer(from: product) {
            case .success(let offer): return .success(offer)
            case .failure(let failure): lastFailure = failure
            }
        }
        return .failure(lastFailure)
    }

    // MARK: - HTML

    static func jsonBlocks(in html: String) -> [String] {
        var blocks: [String] = []
        var rest = html[...]
        while let open = rest.range(of: "<script", options: .caseInsensitive) {
            guard let tagEnd = rest[open.upperBound...].firstIndex(of: ">") else { break }
            let attributes = rest[open.upperBound..<tagEnd].lowercased()
            let bodyStart = rest.index(after: tagEnd)
            guard let close = rest[bodyStart...].range(of: "</script", options: .caseInsensitive) else { break }
            if attributes.contains("application/ld+json") {
                blocks.append(String(rest[bodyStart..<close.lowerBound]))
            }
            rest = rest[close.upperBound...]
        }
        return blocks
    }

    // MARK: - JSON

    static func collectProducts(in json: Any, into products: inout [[String: Any]]) {
        if let list = json as? [Any] {
            for item in list { collectProducts(in: item, into: &products) }
        } else if let object = json as? [String: Any] {
            if types(of: object).contains("product") {
                products.append(object)
            }
            if let graph = object["@graph"] {
                collectProducts(in: graph, into: &products)
            }
            if let entity = object["mainEntity"] {
                collectProducts(in: entity, into: &products)
            }
        }
    }

    static func types(of object: [String: Any]) -> [String] {
        let raw: [String]
        if let one = object["@type"] as? String {
            raw = [one]
        } else {
            raw = object["@type"] as? [String] ?? []
        }
        return raw.map { $0.lowercased().replacingOccurrences(of: "schema:", with: "") }
    }

    static func offer(from product: [String: Any]) -> Result<Offer, Failure> {
        var candidates: [[String: Any]] = []
        if let one = product["offers"] as? [String: Any] {
            candidates = [one]
        } else if let many = product["offers"] as? [[String: Any]] {
            candidates = many
        }
        guard !candidates.isEmpty else { return .failure(.noOffer) }

        // AggregateOffer: gebruik de losse aanbiedingen als die erbij staan,
        // en anders alleen als laagste en hoogste prijs gelijk zijn.
        var offers: [[String: Any]] = []
        for candidate in candidates {
            if types(of: candidate).contains("aggregateoffer") {
                if let nested = candidate["offers"] as? [[String: Any]] {
                    offers += nested
                } else if let low = Euro.parse(json: candidate["lowPrice"]),
                          let high = Euro.parse(json: candidate["highPrice"] ?? candidate["lowPrice"]),
                          low == high, (candidate["offerCount"] as? NSNumber)?.intValue ?? 1 <= 1 {
                    var single = candidate
                    single["price"] = candidate["lowPrice"]
                    offers.append(single)
                } else {
                    return .failure(.ambiguousPrice)
                }
            } else {
                offers.append(candidate)
            }
        }

        let priced = offers.compactMap { raw -> Offer? in
            let price = Euro.parse(json: raw["price"])
                ?? Euro.parse(json: (raw["priceSpecification"] as? [String: Any])?["price"])
            guard let price, price > 0 else { return nil }
            let currency = (raw["priceCurrency"] as? String)
                ?? ((raw["priceSpecification"] as? [String: Any])?["priceCurrency"] as? String)
                ?? "EUR"
            let availability = (raw["availability"] as? String)?.lowercased() ?? ""
            let condition = (raw["itemCondition"] as? String)?.lowercased() ?? ""
            return Offer(
                ean: ean(from: product) ?? ean(from: raw),
                title: (product["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                imageURL: imageURL(from: product["image"]),
                priceCents: price,
                currency: currency,
                // Zonder vermelding gaan we uit van op voorraad en nieuw.
                inStock: availability.isEmpty || availability.hasSuffix("instock")
                    || availability.hasSuffix("limitedavailability")
                    || availability.hasSuffix("onlineonly"),
                isNew: condition.isEmpty || condition.hasSuffix("newcondition"),
                seller: name(from: raw["seller"]))
        }
        guard !priced.isEmpty else { return .failure(.noOffer) }

        // Meerdere aanbiedingen met verschillende prijzen (marktplaats,
        // tweedekans) zijn niet eenduidig.
        let newInStock = priced.filter { $0.isNew && $0.inStock }
        let pool = newInStock.isEmpty ? priced : newInStock
        guard Set(pool.map(\.priceCents)).count == 1, let first = pool.first else {
            return .failure(.ambiguousPrice)
        }
        return .success(first)
    }

    static func ean(from object: [String: Any]) -> String? {
        for key in ["gtin13", "gtin", "gtin14", "gtin12", "gtin8"] {
            let text: String?
            if let string = object[key] as? String {
                text = string
            } else {
                text = (object[key] as? NSNumber)?.stringValue
            }
            if let digits = text?.filter(\.isNumber), (8...14).contains(digits.count) {
                return digits
            }
        }
        return nil
    }

    static func imageURL(from value: Any?) -> URL? {
        if let text = value as? String { return URL(string: text) }
        if let list = value as? [Any] { return imageURL(from: list.first) }
        if let object = value as? [String: Any] {
            return imageURL(from: object["url"] ?? object["contentUrl"])
        }
        return nil
    }

    static func name(from value: Any?) -> String? {
        if let text = value as? String { return text }
        return (value as? [String: Any])?["name"] as? String
    }
}
