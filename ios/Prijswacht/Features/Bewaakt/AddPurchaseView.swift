import PrijswachtCore
import SwiftData
import SwiftUI
import UIKit

/// Aankoop toevoegen in de app: plak de link van de productpagina, of vul
/// alles zelf in.
struct AddPurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var linkText = ""
    @State private var draft: PurchaseDraft?
    @State private var isLoading = false
    @State private var notice: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            Form {
                if draft != nil {
                    confirmation
                } else {
                    start
                }
            }
            .navigationTitle(draft == nil ? LocalizedStringKey("Aankoop toevoegen") : LocalizedStringKey("Klopt dit?"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                if let draft {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Bewaak", action: save)
                            .disabled(!draft.isComplete)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var start: some View {
        Section {
            TextField("Link van de productpagina", text: $linkText, axis: .vertical)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Plak uit klembord", systemImage: "doc.on.clipboard") {
                linkText = UIPasteboard.general.string ?? linkText
            }
            Button(action: lookUp) {
                if isLoading {
                    ProgressView()
                } else {
                    Label("Haal product op", systemImage: "arrow.down.circle")
                }
            }
            .disabled(OfferFetcher.firstURL(in: linkText) == nil || isLoading)
        } header: {
            Text("Met een link")
        } footer: {
            Text("Sneller: tik in Safari of de winkelapp op Deel en kies Prijswacht.")
        }

        Section {
            Button("Vul zelf in", systemImage: "square.and.pencil") {
                draft = PurchaseDraft()
            }
        } footer: {
            Text("Zonder link bewaren we je aankoop en de retourtermijn, maar kunnen we de prijs niet controleren.")
        }
    }

    @ViewBuilder
    private var confirmation: some View {
        if let notice {
            Section {
                Label(notice, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        PurchaseForm(draft: Binding(
            get: { draft ?? PurchaseDraft() },
            set: { draft = $0 }))
    }

    private func lookUp() {
        guard let url = OfferFetcher.firstURL(in: linkText) else { return }
        isLoading = true
        Task {
            let result = await OfferFetcher.fetch(url)
            isLoading = false
            switch result {
            case .success(let offer):
                notice = nil
                draft = PurchaseDraft(url: url, offer: offer)
            case .failure:
                notice = "We konden de prijs niet van deze pagina lezen. Vul de gegevens zelf in; de link bewaren we."
                draft = PurchaseDraft(url: url, offer: nil)
            }
        }
    }

    private func save() {
        guard let purchase = draft?.makePurchase() else { return }
        context.insert(purchase)
        NotificationManager.scheduleReturnReminder(
            id: purchase.id, title: purchase.title, lastDay: purchase.returnLastDay)
        dismiss()
    }
}
