import PrijswachtCore
import SwiftData
import SwiftUI

struct InstellingenView: View {
    @Environment(PlusStore.self) private var plus
    @Environment(\.modelContext) private var context
    @AppStorage(AppSettings.thresholdKey, store: AppGroup.defaults)
    private var thresholdCents = AppSettings.defaultThresholdCents
    @State private var showsPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $thresholdCents, in: 500...10_000, step: 500) {
                        LabeledContent("Meld vanaf") {
                            Text(verbatim: Euro.string(thresholdCents))
                        }
                    }
                } header: {
                    Text("Drempelbedrag")
                } footer: {
                    Text("Je krijgt alleen een melding als de prijs minstens dit bedrag zakt.")
                }

                Section("Abonnement") {
                    if plus.isPlus {
                        Label("Prijswacht Plus is actief", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Theme.money)
                    } else {
                        LabeledContent("Gratis") {
                            Text("\(FreeTier.maxActivePurchases) lopende aankopen")
                        }
                        Button("Bekijk Prijswacht Plus") { showsPaywall = true }
                    }
                    Button("Herstel aankopen") {
                        Task { await plus.restore() }
                    }
                }

                Section {
                    ForEach(ShopStore.directory.shops) { shop in
                        LabeledContent(shop.name) {
                            Text("\(shop.returnDays) dagen retour")
                        }
                    }
                } header: {
                    Text("Winkels")
                } footer: {
                    Text("Voor deze winkels kennen we een profiel. Bij andere winkels rekenen we met de wettelijke bedenktijd van 14 dagen. De voorwaarden van de winkel zijn altijd leidend.")
                }

                Section {
                    Label("We lezen je mail niet.", systemImage: "lock.shield")
                    Label("We versturen niets namens jou.", systemImage: "hand.raised")
                    Label("Je aankopen staan alleen op dit toestel.", systemImage: "iphone")
                    Link("Privacyverklaring", destination: AppLinks.privacy)
                    Link("Voorwaarden", destination: AppLinks.terms)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Prijswacht geeft geen juridisch advies. De app legt uit wat gebruikelijk is en verwijst naar de voorwaarden van de winkel.")
                }

                #if DEBUG
                Section("Ontwikkeling") {
                    Button("Laad voorbeeldaankopen") { SampleData.insert(into: context) }
                    Button("Toon onboarding opnieuw") {
                        AppGroup.defaults.set(false, forKey: AppSettings.onboardedKey)
                    }
                }
                #endif
            }
            .navigationTitle("Instellingen")
            .sheet(isPresented: $showsPaywall) { PaywallView(reason: .settings) }
        }
    }
}

#if DEBUG
/// Verzonnen aankopen om de schermen te bekijken zonder server.
@MainActor
enum SampleData {
    static func insert(into context: ModelContext) {
        let calendar = Calendar.current
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        }
        let shop = ShopProfile(id: "voorbeeldwinkel", name: "Voorbeeldwinkel", domains: [], returnCostCents: 695)

        let dropped = Purchase(
            title: "Voorbeeld: koptelefoon", shop: shop, paidCents: 29_900,
            purchaseDate: daysAgo(10), deliveryDate: daysAgo(8), orderNumber: "VB-1001")
        dropped.currentCents = 26_100
        dropped.confirmedCents = 26_100
        dropped.confirmedAt = .now
        dropped.lastCheckedAt = .now

        let watching = Purchase(
            title: "Voorbeeld: stofzuiger", shop: shop, paidCents: 44_900,
            purchaseDate: daysAgo(3), deliveryDate: daysAgo(2))
        watching.currentCents = 44_900
        watching.lastCheckedAt = .now

        let ending = Purchase(
            title: "Voorbeeld: sneakers", shop: shop, paidCents: 11_995,
            purchaseDate: daysAgo(13), deliveryDate: daysAgo(12))

        for purchase in [dropped, watching, ending] {
            context.insert(purchase)
        }
    }
}
#endif
