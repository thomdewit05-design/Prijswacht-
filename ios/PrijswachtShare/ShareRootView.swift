import PrijswachtCore
import SwiftData
import SwiftUI

struct ShareRootView: View {
    let loadURL: () async -> URL?
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Purchase> { $0.archivedAt == nil }) private var purchases: [Purchase]

    private enum Phase {
        case loading, form, noLink, limitReached
    }

    @State private var phase = Phase.loading
    @State private var draft = PurchaseDraft()
    @State private var couldNotReadPrice = false

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    ProgressView("Product ophalen…")
                case .form:
                    Form {
                        if couldNotReadPrice {
                            Section {
                                Label("We konden de prijs niet van deze pagina lezen. Vul de gegevens zelf in; de link bewaren we.", systemImage: "info.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        PurchaseForm(draft: $draft)
                    }
                case .noLink:
                    ContentUnavailableView(
                        "Geen productpagina gevonden", systemImage: "link",
                        description: Text("Deel de pagina van het product zelf, vanuit Safari of de winkelapp."))
                case .limitReached:
                    ContentUnavailableView(
                        "Je bewaakt al \(FreeTier.maxActivePurchases) aankopen", systemImage: "eye",
                        description: Text("Open Prijswacht om met Plus meer aankopen te bewaken."))
                }
            }
            .navigationTitle("Klopt dit?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer", action: onClose)
                }
                if phase == .form {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Bewaak", action: save)
                            .disabled(!draft.isComplete)
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        let running = purchases.filter { $0.isRunning() }.count
        guard FreeTier.canAddPurchase(activeCount: running, isPlus: AppSettings.isPlus) else {
            phase = .limitReached
            return
        }
        guard let url = await loadURL() else {
            phase = .noLink
            return
        }
        switch await OfferFetcher.fetch(url) {
        case .success(let offer):
            draft = PurchaseDraft(url: url, offer: offer)
        case .failure:
            couldNotReadPrice = true
            draft = PurchaseDraft(url: url, offer: nil)
        }
        phase = .form
    }

    private func save() {
        guard let purchase = draft.makePurchase() else { return }
        context.insert(purchase)
        try? context.save()
        onClose()
    }
}
