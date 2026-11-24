import Foundation
import StoreKit

/// Prijswacht Plus via StoreKit 2. RevenueCat komt hier in fase 4 tussen,
/// zodat de betaalmuur zonder nieuwe release te testen is.
@MainActor
@Observable
final class PlusStore {
    static let productIDs = ["nl.prijswacht.plus.jaar", "nl.prijswacht.plus.maand"]

    private(set) var isPlus = AppSettings.isPlus
    private(set) var products: [Product] = []
    private(set) var isPurchasing = false
    var errorMessage: String?

    private var updates: Task<Void, Never>?

    func start() async {
        if updates == nil {
            updates = Task { [weak self] in
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update {
                        await transaction.finish()
                    }
                    await self?.refreshEntitlement()
                }
            }
        }
        await refreshEntitlement()
        await loadProducts()
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        let loaded = (try? await Product.products(for: Self.productIDs)) ?? []
        // Jaar eerst: dat is het hoofdabonnement.
        products = loaded.sorted { $0.price > $1.price }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            if case .success(.verified(let transaction)) = result {
                await transaction.finish()
            }
            await refreshEntitlement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPlus = active
        AppSettings.isPlus = active
    }
}
