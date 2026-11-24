import PrijswachtCore
import SwiftData
import SwiftUI

/// Gegevens van een aankoop terwijl de gebruiker ze bevestigt.
struct PurchaseDraft {
    var title = ""
    var shop: ShopProfile?
    var shopName = ""
    var priceText = ""
    var purchaseDate = Date.now
    var isDelivered = false
    var deliveryDate = Date.now
    var orderNumber = ""
    var productURL: URL?
    var imageURL: URL?
    var ean: String?
    /// Prijs die de winkel nu toont, als we die konden lezen.
    var currentCents: Int?

    init() {}

    init(url: URL, offer: Offer?) {
        productURL = url
        let profile = ShopStore.directory.shopOrUnknown(for: url)
        shop = profile
        shopName = profile.name
        if let offer {
            title = offer.title ?? ""
            imageURL = offer.imageURL
            ean = offer.ean
            currentCents = offer.priceCents
            priceText = Euro.string(offer.priceCents).replacingOccurrences(of: "€", with: "")
        }
    }

    var paidCents: Int? {
        guard let cents = Euro.parse(priceText), cents > 0 else { return nil }
        return cents
    }

    var resolvedShop: ShopProfile {
        if let shop, shop.name == shopName || shopName.isEmpty { return shop }
        let name = shopName.trimmingCharacters(in: .whitespaces)
        return ShopProfile(id: name.lowercased(), name: name, domains: [])
    }

    var isComplete: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !shopName.trimmingCharacters(in: .whitespaces).isEmpty
            && paidCents != nil
    }

    @MainActor
    func makePurchase() -> Purchase? {
        guard isComplete, let paidCents else { return nil }
        let purchase = Purchase(
            title: title.trimmingCharacters(in: .whitespaces),
            shop: resolvedShop, paidCents: paidCents, purchaseDate: purchaseDate,
            deliveryDate: isDelivered ? deliveryDate : nil,
            productURL: productURL, imageURL: imageURL, ean: ean,
            orderNumber: orderNumber.isEmpty ? nil : orderNumber)
        purchase.currentCents = currentCents
        purchase.lastCheckedAt = currentCents == nil ? nil : .now
        return purchase
    }
}

/// Bevestigingsscherm: de gebruiker controleert product, betaalde prijs en
/// koopdatum. Gebruikt door de app en door de delen-extensie.
struct PurchaseForm: View {
    @Binding var draft: PurchaseDraft

    var body: some View {
        Section("Product") {
            TextField("Naam van het product", text: $draft.title, axis: .vertical)
            TextField("Winkel", text: $draft.shopName)
                .textInputAutocapitalization(.words)
        }

        Section {
            HStack {
                Text(verbatim: "€")
                    .foregroundStyle(.secondary)
                TextField("Betaalde prijs", text: $draft.priceText)
                    .keyboardType(.decimalPad)
            }
            DatePicker("Gekocht op", selection: $draft.purchaseDate, in: ...Date.now, displayedComponents: .date)
            Toggle("Al geleverd", isOn: $draft.isDelivered)
            if draft.isDelivered {
                DatePicker(
                    "Geleverd op", selection: $draft.deliveryDate,
                    in: draft.purchaseDate...Date.now, displayedComponents: .date)
            }
        } header: {
            Text("Jouw aankoop")
        } footer: {
            Text("Vul in wat je zelf betaald hebt. De retourtermijn telt vanaf de levering.")
        }

        Section {
            TextField("Bestelnummer (optioneel)", text: $draft.orderNumber)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } footer: {
            Text("Het bestelnummer komt in het bericht aan de winkel te staan.")
        }

        Section {
            let shop = draft.resolvedShop
            LabeledContent("Retourtermijn") {
                Text("\(shop.returnDays) dagen")
            }
        } footer: {
            if draft.resolvedShop.verified {
                Text("Volgens de voorwaarden van de winkel.")
            } else {
                Text("We rekenen met de wettelijke bedenktijd van 14 dagen. Controleer de voorwaarden van de winkel; er gelden uitzonderingen.")
            }
        }
    }
}
