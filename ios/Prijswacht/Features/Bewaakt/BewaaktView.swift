import PrijswachtCore
import SwiftData
import SwiftUI

/// Tab "Bewaakt": lopende aankopen, dalingen bovenaan.
struct BewaaktView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PlusStore.self) private var plus
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Purchase> { $0.archivedAt == nil }, sort: \Purchase.createdAt, order: .reverse)
    private var purchases: [Purchase]

    @State private var isAdding = false
    @State private var showsPaywall = false

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.watchedPath) {
            Group {
                if purchases.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Bewaakt")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Aankoop toevoegen", systemImage: "plus", action: add)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                PurchaseDestination(id: id)
            }
            .sheet(isPresented: $isAdding) { AddPurchaseView() }
            .sheet(isPresented: $showsPaywall) { PaywallView(reason: .purchaseLimit) }
        }
    }

    private var drops: [Purchase] {
        purchases.filter { $0.dropCents > 0 }.sorted { $0.dropCents > $1.dropCents }
    }

    private var others: [Purchase] {
        purchases.filter { $0.dropCents == 0 }.sorted { $0.daysRemaining() > $1.daysRemaining() }
            .sorted { ($0.daysRemaining() >= 0 ? 0 : 1) < ($1.daysRemaining() >= 0 ? 0 : 1) }
    }

    private var list: some View {
        List {
            if !drops.isEmpty {
                Section("Prijs gedaald") {
                    ForEach(drops) { row($0) }
                }
            }
            if !others.isEmpty {
                Section(drops.isEmpty ? LocalizedStringKey("") : LocalizedStringKey("Wordt bewaakt")) {
                    ForEach(others) { row($0) }
                }
            }
            Section {
            } footer: {
                Text("Trek omlaag om te verversen. Een daling telt pas na een tweede controle, minstens een uur later.")
            }
        }
        .refreshable { await PriceChecker.checkAll(in: context) }
    }

    private func row(_ purchase: Purchase) -> some View {
        NavigationLink(value: purchase.id) {
            PurchaseRow(purchase: purchase)
        }
        .swipeActions {
            Button("Archiveer", systemImage: "archivebox") {
                purchase.archivedAt = .now
                NotificationManager.cancelReturnReminder(id: purchase.id)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nog niets bewaakt", systemImage: "eye")
        } description: {
            Text("Voeg een aankoop toe. Daalt de prijs binnen je retourtermijn, dan hoor je het.")
        } actions: {
            Button("Aankoop toevoegen", action: add)
                .buttonStyle(.borderedProminent)
        }
    }

    private func add() {
        let running = purchases.filter { $0.isRunning() }.count
        if FreeTier.canAddPurchase(activeCount: running, isPlus: plus.isPlus) {
            isAdding = true
        } else {
            showsPaywall = true
        }
    }
}

struct PurchaseRow: View {
    let purchase: Purchase

    var body: some View {
        HStack(spacing: 12) {
            ProductImage(url: purchase.imageURL)
            VStack(alignment: .leading, spacing: 4) {
                Text(purchase.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(verbatim: "\(purchase.shopName) · \(Euro.string(purchase.paidCents))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DaysBadge(days: purchase.daysRemaining())
            }
            Spacer(minLength: 8)
            if purchase.dropCents > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    AmountText(cents: purchase.dropCents)
                    Text("goedkoper")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let current = purchase.currentCents {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: Euro.string(current))
                        .font(.subheadline.monospacedDigit())
                    Text("nu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
