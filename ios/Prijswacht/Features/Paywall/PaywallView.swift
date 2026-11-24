import PrijswachtCore
import StoreKit
import SwiftUI

struct PaywallView: View {
    enum Reason {
        case purchaseLimit, route, settings
    }

    let reason: Reason
    @Environment(PlusStore.self) private var plus
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prijswacht Plus")
                            .font(.largeTitle.bold())
                        Text(intro)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("Met Plus") {
                    Label("Onbeperkt aankopen bewaken", systemImage: "infinity")
                    Label("Bij elke daling het routescherm en een kant-en-klaar bericht", systemImage: "envelope")
                    Label("Eén gevonden prijsdaling kan het jaarbedrag al goedmaken", systemImage: "eurosign.circle")
                }

                Section {
                    if plus.isPlus {
                        Label("Je hebt Prijswacht Plus", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Theme.money)
                    } else if plus.products.isEmpty {
                        Text("De abonnementen zijn nu niet beschikbaar. Probeer het later opnieuw.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(plus.products) { product in
                            Button {
                                Task { await plus.purchase(product) }
                            } label: {
                                HStack {
                                    Text(product.displayName)
                                    Spacer()
                                    Text(verbatim: product.displayPrice)
                                        .fontWeight(.semibold)
                                }
                            }
                            .disabled(plus.isPurchasing)
                        }
                    }
                    Button("Herstel aankopen") {
                        Task { await plus.restore() }
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Het abonnement wordt automatisch verlengd tot je opzegt. Opzeggen kan altijd via de instellingen van je Apple-account.")
                        Text("Prijswacht helpt je om geld terug te vragen. Of je het terugkrijgt, bepaalt de winkel.")
                        HStack(spacing: 16) {
                            Link("Voorwaarden", destination: AppLinks.terms)
                            Link("Privacy", destination: AppLinks.privacy)
                        }
                    }
                }

                if let error = plus.errorMessage {
                    Section {
                        Text(verbatim: error).foregroundStyle(.red)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluit") { dismiss() }
                }
            }
            .onChange(of: plus.isPlus) { _, isPlus in
                if isPlus { dismiss() }
            }
        }
    }

    private var intro: LocalizedStringKey {
        switch reason {
        case .purchaseLimit:
            "Gratis bewaak je \(FreeTier.maxActivePurchases) lopende aankopen tegelijk. Met Plus bewaak je alles wat je koopt."
        case .route:
            "Je eerste treffer was gratis. Met Plus zetten we bij elke daling de route en het bericht voor je klaar."
        case .settings:
            "Bewaak alles wat je koopt, en krijg bij elke daling de route en het bericht."
        }
    }
}

/// Nog in te vullen voor de lancering: echte pagina's op het eigen domein.
enum AppLinks {
    static let terms = URL(string: "https://prijswacht.example/voorwaarden")!
    static let privacy = URL(string: "https://prijswacht.example/privacy")!
}
