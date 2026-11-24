import Foundation
import PrijswachtCore
import SwiftData

/// Prijscontrole vanaf het toestel. Tijdelijk: de dagelijkse controle hoort
/// op de server (fase 1). De regels zijn dezelfde: een daling telt pas na
/// een tweede controle, minstens een uur later.
@MainActor
enum PriceChecker {
    /// Controleert alle lopende aankopen met een productlink.
    static func checkAll(in context: ModelContext, now: Date = .now) async {
        let purchases = (try? context.fetch(FetchDescriptor<Purchase>())) ?? []
        for purchase in purchases where !purchase.isArchived && purchase.productURL != nil {
            await check(purchase, now: now)
        }
        try? context.save()
    }

    static func check(_ purchase: Purchase, now: Date = .now) async {
        guard let url = purchase.productURL,
              case .success(let offer) = await OfferFetcher.fetch(url)
        else { return }

        // Ander product dan de aankoop (andere variant op dezelfde link):
        // niet vergelijken.
        if let known = purchase.ean, let seen = offer.ean, known != seen { return }

        purchase.currentCents = offer.priceCents
        purchase.lastCheckedAt = now

        let decision = DropDetector.evaluate(
            offer: offer, paidCents: purchase.paidCents,
            thresholdCents: AppSettings.thresholdCents, expectedSeller: purchase.shopName,
            pending: purchase.pendingDrop, now: now)

        switch decision {
        case .none:
            purchase.pendingDrop = nil
            purchase.confirmedCents = nil
            purchase.confirmedAt = nil
        case .pending(let pending):
            purchase.pendingDrop = pending
        case .confirmed(let priceCents, let dropCents):
            let isNew = purchase.confirmedCents != priceCents
            purchase.confirmedCents = priceCents
            purchase.confirmedAt = purchase.confirmedAt ?? now
            if isNew {
                NotificationManager.notifyDrop(
                    id: purchase.id, title: purchase.title, dropCents: dropCents,
                    daysRemaining: purchase.daysRemaining(now: now))
            }
        }
    }

    /// Zet de retourherinneringen opnieuw, ook voor aankopen die via de
    /// delen-extensie zijn toegevoegd.
    static func refreshReminders(in context: ModelContext, now: Date = .now) async {
        let purchases = (try? context.fetch(FetchDescriptor<Purchase>())) ?? []
        for purchase in purchases where !purchase.isArchived {
            NotificationManager.scheduleReturnReminder(
                id: purchase.id, title: purchase.title, lastDay: purchase.returnLastDay, now: now)
        }
    }
}
