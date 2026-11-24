import PrijswachtCore
import SwiftData
import SwiftUI
import UIKit

/// Het routescherm: van melding naar geld in twee tikken.
struct RouteView: View {
    @Bindable var purchase: Purchase
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(PlusStore.self) private var plus
    @Query private var outcomes: [Outcome]

    @State private var message: MessageComposer.Message?
    @State private var showsPaywall = false
    @State private var celebrates = false
    @State private var isChecking = false

    private var shop: ShopProfile {
        ShopStore.shop(id: purchase.shopID, fallbackName: purchase.shopName)
    }

    private var options: [RouteOption] {
        guard purchase.dropCents > 0 else { return [] }
        return RouteAdvisor.options(for: RouteInput(
            paidCents: purchase.paidCents, sameShopCents: purchase.confirmedCents,
            shop: shop, daysRemaining: purchase.daysRemaining(),
            thresholdCents: AppSettings.thresholdCents, refused: purchase.refusedRoutes))
    }

    var body: some View {
        List {
            header
            if purchase.reclaimedCents > 0 {
                reclaimed
            } else if let best = options.first {
                routeSection(best, isBest: true)
                ForEach(options.dropFirst(), id: \.route) { routeSection($0, isBest: false) }
                honesty
            } else {
                waiting
            }
            details
        }
        .navigationTitle(purchase.shopName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $message) { MessageSheet(message: $0, shop: shop) }
        .sheet(isPresented: $showsPaywall) { PaywallView(reason: .route) }
        .sensoryFeedback(.success, trigger: celebrates)
    }

    // MARK: - Onderdelen

    private var header: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ProductImage(url: purchase.imageURL, size: 64)
                    Text(purchase.title)
                        .font(.headline)
                }
                if purchase.dropCents > 0, let now = purchase.confirmedCents {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        AmountText(cents: purchase.dropCents, style: .largeTitle)
                        Text("goedkoper")
                            .font(.title3)
                    }
                    Text(verbatim: "\(Euro.string(purchase.paidCents)) → \(Euro.string(now))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                remainingTime
            }
            .padding(.vertical, 4)
        }
    }

    private var remainingTime: some View {
        let days = purchase.daysRemaining()
        return Group {
            switch days {
            case ..<0: Text("De retourtermijn is verlopen")
            case 0: Text("Vandaag is de laatste dag om te retourneren")
            case 1: Text("Nog 1 dag om te retourneren")
            default: Text("Nog \(days) dagen om te retourneren")
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(days <= 3 && days >= 0 ? Theme.warning : .primary)
    }

    private func routeSection(_ option: RouteOption, isBest: Bool) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title(for: option.route))
                        .font(.headline)
                    Spacer()
                    if let net = option.netCents {
                        AmountText(cents: net, style: .headline)
                    }
                }
                Text(explanation(for: option))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let rate = successRate(for: option.route) {
                    Text("Bij \(purchase.shopName) lukte dit \(rate.succeeded) van de \(rate.total) keer.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)

            Button("Bericht klaarzetten", systemImage: "envelope") { prepareMessage(option.route) }
                .fontWeight(isBest ? .semibold : .regular)
            Button("Gelukt", systemImage: "checkmark.circle") { succeed(option) }
            Button("Geweigerd", systemImage: "xmark.circle", role: .destructive) { refuse(option) }
        } header: {
            Text(isBest ? "Aanbevolen route" : "Andere route")
        }
    }

    private var honesty: some View {
        Section {
        } footer: {
            Text("Winkels zijn niet verplicht het verschil terug te betalen. Retourneren binnen de bedenktijd mag bij online aankopen wel, met uitzonderingen; kijk in de voorwaarden van de winkel. Jij verstuurt het bericht zelf.")
        }
    }

    private var reclaimed: some View {
        Section {
            HStack {
                Label("Teruggekregen", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.money)
                Spacer()
                AmountText(cents: purchase.reclaimedCents)
            }
        }
    }

    private var waiting: some View {
        Section {
            if purchase.dropCents > 0 {
                Label("De winkel heeft alle routes geweigerd of de retourtermijn is voorbij.", systemImage: "hand.raised")
            } else if purchase.productURL == nil {
                Label("Zonder link kunnen we de prijs niet controleren. De retourherinnering staat wel aan.", systemImage: "link")
            } else if purchase.pendingDrop != nil {
                Label("We zagen een lagere prijs en controleren die nog een keer voordat we iets melden.", systemImage: "clock")
            } else {
                Label("Nog geen daling. Je hoort het als de prijs zakt.", systemImage: "eye")
            }
            if purchase.productURL != nil {
                Button {
                    isChecking = true
                    Task {
                        await PriceChecker.check(purchase)
                        isChecking = false
                    }
                } label: {
                    if isChecking { ProgressView() } else { Text("Controleer nu") }
                }
                .disabled(isChecking)
            }
        }
        .font(.subheadline)
    }

    private var details: some View {
        Section("Aankoop") {
            LabeledContent("Betaald") { Text(verbatim: Euro.string(purchase.paidCents)) }
            if let current = purchase.currentCents {
                LabeledContent("Prijs nu") { Text(verbatim: Euro.string(current)) }
            }
            LabeledContent("Gekocht op") { Text(purchase.purchaseDate, style: .date) }
            LabeledContent("Retourneren tot en met") { Text(purchase.returnLastDay, style: .date) }
            if let checked = purchase.lastCheckedAt {
                LabeledContent("Laatst gecontroleerd") { Text(checked, style: .relative) }
            }
            TextField("Bestelnummer", text: Binding(
                get: { purchase.orderNumber ?? "" },
                set: { purchase.orderNumber = $0.isEmpty ? nil : $0 }))
                .autocorrectionDisabled()
            if let url = purchase.productURL {
                Link("Open productpagina", destination: url)
            }
            Button("Verwijder aankoop", role: .destructive) {
                NotificationManager.cancelReturnReminder(id: purchase.id)
                context.delete(purchase)
                dismiss()
            }
        }
    }

    // MARK: - Teksten

    private func title(for route: Route) -> LocalizedStringKey {
        switch route {
        case .askDifference: "Vraag het verschil"
        case .returnAndReorder: "Retourneer en bestel opnieuw"
        case .priceGuarantee: "Claim de laagsteprijsgarantie"
        }
    }

    private func explanation(for option: RouteOption) -> LocalizedStringKey {
        switch option.route {
        case .askDifference:
            return "Vraag de winkel vriendelijk om het verschil. Geen recht, wel vaak coulance; soms een tegoedbon in plaats van geld."
        case .returnAndReorder:
            if let cost = shop.returnCostCents {
                return cost == 0
                    ? "Stuur terug en bestel opnieuw voor de lagere prijs. Retourneren is bij deze winkel gratis."
                    : "Stuur terug en bestel opnieuw voor de lagere prijs. Na \(Euro.string(cost)) retourkosten."
            }
            return "Stuur terug en bestel opnieuw voor de lagere prijs. De retourkosten van deze winkel kennen we niet; trek die er zelf af. Controleer eerst of het product nog op voorraad is."
        case .priceGuarantee:
            return "Deze winkel belooft de laagste prijs. Stuur het bewijs mee in het formaat dat de winkel vraagt."
        }
    }

    private func successRate(for route: Route) -> SuccessRate? {
        let relevant = outcomes.filter { $0.shopID == purchase.shopID && $0.route == route }
        let rate = SuccessRate(succeeded: relevant.filter(\.succeeded).count, total: relevant.count)
        return rate.percentage == nil ? nil : rate
    }

    // MARK: - Acties

    private func prepareMessage(_ route: Route) {
        // De eerste treffer rondt een gratis gebruiker altijd gratis af.
        let completed = outcomes.filter { $0.purchaseID != purchase.id }.count
        guard FreeTier.canOpenRoute(completedOutcomes: completed, isPlus: plus.isPlus) else {
            showsPaywall = true
            return
        }
        message = MessageComposer.message(for: route, context: .init(
            productTitle: purchase.title, shopName: purchase.shopName,
            orderNumber: purchase.orderNumber, purchaseDate: purchase.purchaseDate,
            paidCents: purchase.paidCents, newCents: purchase.confirmedCents ?? purchase.paidCents,
            productURL: purchase.productURL, observedAt: purchase.lastCheckedAt ?? .now))
    }

    private func succeed(_ option: RouteOption) {
        let amount = option.netCents ?? option.grossCents
        context.insert(Outcome(purchase: purchase, route: option.route, succeeded: true, amountCents: amount))
        purchase.reclaimedCents = amount
        purchase.archivedAt = .now
        NotificationManager.cancelReturnReminder(id: purchase.id)
        celebrates.toggle()
    }

    private func refuse(_ option: RouteOption) {
        context.insert(Outcome(purchase: purchase, route: option.route, succeeded: false, amountCents: 0))
        withAnimation {
            purchase.refusedRoutes.insert(option.route)
        }
    }
}

/// Zoekt de aankoop op, ook als die intussen gearchiveerd is.
struct PurchaseDestination: View {
    @Query private var matches: [Purchase]

    init(id: UUID) {
        _matches = Query(filter: #Predicate<Purchase> { $0.id == id })
    }

    var body: some View {
        if let purchase = matches.first {
            RouteView(purchase: purchase)
        } else {
            ContentUnavailableView("Aankoop niet gevonden", systemImage: "questionmark.circle")
        }
    }
}

/// Het kant-en-klare bericht. De gebruiker verstuurt het zelf.
struct MessageSheet: View {
    let message: MessageComposer.Message
    let shop: ShopProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var copied = false

    private var fullText: String { "\(message.subject)\n\n\(message.body)" }

    private var mailURL: URL? {
        guard let email = shop.contactEmail else { return nil }
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = email
        parts.queryItems = [
            URLQueryItem(name: "subject", value: message.subject),
            URLQueryItem(name: "body", value: message.body),
        ]
        return parts.url
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Onderwerp") {
                    Text(message.subject)
                }
                Section("Bericht") {
                    Text(message.body)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                Section {
                    if let mailURL {
                        Button("Open in Mail", systemImage: "envelope") { openURL(mailURL) }
                    }
                    if let contact = shop.contactURL {
                        Button("Kopieer en open contactpagina", systemImage: "safari") {
                            UIPasteboard.general.string = fullText
                            openURL(contact)
                        }
                    }
                    Button(copied ? LocalizedStringKey("Gekopieerd") : LocalizedStringKey("Kopieer bericht"), systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = fullText
                        copied = true
                    }
                    ShareLink(item: fullText) {
                        Label("Deel via een andere app", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Zet je naam eronder en verstuur het bericht via de klantenservice van \(shop.name). Laat daarna weten of het gelukt is.")
                }
            }
            .navigationTitle("Bericht voor \(shop.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
    }
}
