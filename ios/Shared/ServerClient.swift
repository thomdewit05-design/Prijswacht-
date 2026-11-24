import Foundation
import PrijswachtCore

/// Verbinding met de Prijswacht-server (Supabase Edge Functions). Zonder
/// ingevulde serverinstellingen werkt de app zelfstandig en haalt hij prijzen
/// zelf op.
enum ServerClient {
    struct Config {
        let baseURL: URL
        let anonKey: String
    }

    /// Uit Info.plist: PrijswachtServerURL en PrijswachtAnonKey.
    static let config: Config? = {
        let info = Bundle.main.infoDictionary
        guard let raw = info?["PrijswachtServerURL"] as? String, !raw.isEmpty,
              let url = URL(string: raw), url.scheme == "https",
              let key = info?["PrijswachtAnonKey"] as? String, !key.isEmpty
        else { return nil }
        return Config(baseURL: url, anonKey: key)
    }()

    /// Willekeurig id van deze installatie. Er zijn geen accounts.
    static var installID: UUID {
        let key = "installID"
        if let stored = AppGroup.defaults.string(forKey: key), let id = UUID(uuidString: stored) {
            return id
        }
        let id = UUID()
        AppGroup.defaults.set(id.uuidString, forKey: key)
        return id
    }

    static var apnsToken: String? {
        get { AppGroup.defaults.string(forKey: "apnsToken") }
        set { AppGroup.defaults.set(newValue, forKey: "apnsToken") }
    }

    // MARK: - Lookup

    enum LookupResult {
        case offer(Offer)
        /// De server kon de prijs niet lezen; `reason` is de reden van de adapter.
        case unreadable(reason: String)
        case unavailable
    }

    private struct LookupResponse: Decodable {
        struct RemoteOffer: Decodable {
            let ean: String?
            let title: String?
            let imageUrl: String?
            let price: Int
            let currency: String
            let inStock: Bool
            let isNew: Bool
            let seller: String?
        }

        let ok: Bool
        let reason: String?
        let offer: RemoteOffer?
    }

    static func lookup(_ url: URL) async -> LookupResult {
        struct Body: Encodable { let url: String }
        guard let response: LookupResponse = await post("lookup", body: Body(url: url.absoluteString)) else {
            return .unavailable
        }
        guard response.ok, let remote = response.offer else {
            return .unreadable(reason: response.reason ?? "")
        }
        return .offer(Offer(
            ean: remote.ean, title: remote.title, imageURL: remote.imageUrl.flatMap(URL.init(string:)),
            priceCents: remote.price, currency: remote.currency, inStock: remote.inStock,
            isNew: remote.isNew, seller: remote.seller))
    }

    // MARK: - Sync

    struct SyncPurchase: Encodable {
        let id: String
        let title: String
        let url: String?
        let ean: String?
        let shopId: String
        let shopName: String
        let paidCents: Int
        let purchaseDate: String
        let returnLastDay: String
        let archived: Bool
    }

    struct SyncOutcome: Encodable {
        let id: String
        let purchaseId: String
        let shopId: String
        let route: String
        let succeeded: Bool
        let amountCents: Int
        let decidedAt: String
    }

    struct SyncRequest: Encodable {
        let installId: String
        let apnsToken: String?
        let thresholdCents: Int
        let purchases: [SyncPurchase]
        let outcomes: [SyncOutcome]
    }

    struct RemoteState: Decodable {
        let id: String
        let currentCents: Int?
        let checkedAt: String?
        let confirmedCents: Int?
    }

    private struct SyncResponse: Decodable {
        let purchases: [RemoteState]
    }

    /// Stuurt de aankopen naar de server en geeft per aankoop de laatste
    /// stand terug. nil als de server niet bereikbaar is.
    static func sync(_ request: SyncRequest) async -> [RemoteState]? {
        let response: SyncResponse? = await post("sync", body: request)
        return response?.purchases
    }

    /// JJJJ-MM-DD in de tijdzone van het toestel.
    static func dayString(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Tijdstip van de server, met of zonder fracties van seconden.
    static func date(fromTimestamp text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    // MARK: - HTTP

    private static func post<Body: Encodable, Response: Decodable>(_ function: String, body: Body) async -> Response? {
        guard let config, let payload = try? JSONEncoder().encode(body) else { return nil }
        var request = URLRequest(
            url: config.baseURL.appendingPathComponent("functions/v1/\(function)"), timeoutInterval: 20)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(Response.self, from: data)
    }
}
