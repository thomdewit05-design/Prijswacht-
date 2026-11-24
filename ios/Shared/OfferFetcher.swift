import Foundation
import PrijswachtCore

/// Vraagt product en prijs van een productpagina op. Met een ingestelde
/// server loopt dat via de adapters daar; anders, of als de server de winkel
/// niet kent, leest de app de gestructureerde gegevens zelf van de pagina.
enum OfferFetcher {
    enum Failure: Error {
        case network
        case unreadable
    }

    static func fetch(_ url: URL) async -> Result<Offer, Failure> {
        switch await ServerClient.lookup(url) {
        case .offer(let offer):
            return .success(offer)
        case .unreadable(let reason) where reason != "geen-adapter":
            // De adapter kent deze winkel maar kon de prijs niet lezen, of de
            // winkel staat ophalen niet toe: dan proberen we het niet zelf.
            return .failure(.unreadable)
        case .unreadable, .unavailable:
            return await fetchFromPage(url)
        }
    }

    /// Leest de pagina rechtstreeks vanaf het toestel.
    static func fetchFromPage(_ url: URL) async -> Result<Offer, Failure> {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("nl-NL,nl;q=0.9", forHTTPHeaderField: "Accept-Language")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false
        else { return .failure(.network) }

        let html = String(decoding: data, as: UTF8.self)
        return JSONLDOfferParser.parse(html: html).mapError { _ in Failure.unreadable }
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
