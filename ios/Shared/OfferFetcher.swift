import Foundation
import PrijswachtCore

/// Haalt een productpagina op en leest product en prijs uit de
/// gestructureerde gegevens. Tijdelijke bron tot de prijsmotor op de server
/// draait; daarna vraagt de app de server.
enum OfferFetcher {
    enum Failure: Error {
        case network
        case unreadable(JSONLDOfferParser.Failure)
    }

    static func fetch(_ url: URL) async -> Result<Offer, Failure> {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("nl-NL,nl;q=0.9", forHTTPHeaderField: "Accept-Language")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false
        else { return .failure(.network) }

        let html = String(decoding: data, as: UTF8.self)
        return JSONLDOfferParser.parse(html: html).mapError(Failure.unreadable)
    }

    /// Eerste weblink in een stuk gedeelde tekst.
    static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        let match = detector?.matches(in: text, options: [], range: range).first { result in
            result.url?.scheme?.hasPrefix("http") ?? false
        }
        return match?.url
    }
}
