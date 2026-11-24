import Foundation
import PrijswachtCore
import SwiftData
import WidgetKit

/// Houdt de prijzen bij. Met een ingestelde server doet die de dagelijkse
/// controle en haalt de app alleen de stand op. Zonder server controleert de
/// app zelf, met dezelfde regels: een daling telt pas na een tweede
/// controle, minstens een uur later.
@MainActor
enum PriceChecker {
    /// Ververst alle lopende aankopen.
    static func checkAll(in context: ModelContext, now: Date = .now) async {
        if ServerClient.config != nil, await sync(in: context) {
            return
        }
        let purchases = (try? context.fetch(FetchDescriptor<Purchase>())) ?? []
        for purchase in purchases where !purchase.isArchived && purchase.productURL != nil {
            await check(purchase, now: now)
        }
        try? context.save()
    }

    /// Eén aankoop vanaf het toestel controleren.
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

    /// Stuurt aankopen en uitkomsten naar de server en neemt de stand over.
    /// Geeft false als er geen server is of die niet bereikbaar was.
    @discardableResult
    static func sync(in context: ModelContext) async -> Bool {
        guard ServerClient.config != nil else { return false }
        let purchases = (try? context.fetch(FetchDescriptor<Purchase>())) ?? []
        let outcomes = (try? context.fetch(FetchDescriptor<Outcome>())) ?? []
        let timestamps = ISO8601DateFormatter()

        let request = ServerClient.SyncRequest(
            installId: ServerClient.installID.uuidString,
            apnsToken: ServerClient.apnsToken,
            thresholdCents: AppSettings.thresholdCents,
            purchases: purchases.map { purchase in
                ServerClient.SyncPurchase(
                    id: purchase.id.uuidString, title: purchase.title,
                    url: purchase.productURLString, ean: purchase.ean,
                    shopId: purchase.shopID, shopName: purchase.shopName,
                    paidCents: purchase.paidCents,
                    purchaseDate: ServerClient.dayString(purchase.purchaseDate),
                    returnLastDay: ServerClient.dayString(purchase.returnLastDay),
                    archived: purchase.isArchived)
            },
            outcomes: outcomes.compactMap { outcome -> ServerClient.SyncOutcome? in
                guard let route = outcome.route else { return nil }
                return ServerClient.SyncOutcome(
                    id: outcome.id.uuidString, purchaseId: outcome.purchaseID.uuidString,
                    shopId: outcome.shopID, route: route.rawValue, succeeded: outcome.succeeded,
                    amountCents: outcome.amountCents, decidedAt: timestamps.string(from: outcome.date))
            })

        guard let states = await ServerClient.sync(request) else { return false }
        for state in states {
            guard let id = UUID(uuidString: state.id),
                  let purchase = purchases.first(where: { $0.id == id }), !purchase.isArchived
            else { continue }
            purchase.currentCents = state.currentCents ?? purchase.currentCents
            purchase.lastCheckedAt = state.checkedAt.flatMap(ServerClient.date(fromTimestamp:)) ?? purchase.lastCheckedAt
            if purchase.confirmedCents != state.confirmedCents {
                purchase.confirmedCents = state.confirmedCents
                purchase.confirmedAt = state.confirmedCents == nil ? nil : .now
            }
        }
        try? context.save()
        return true
    }

    /// Werkt de gegevens voor de widget bij.
    static func updateWidget(in context: ModelContext, now: Date = .now) {
        let purchases = ((try? context.fetch(FetchDescriptor<Purchase>())) ?? []).filter { !$0.isArchived }
        let outcomes = (try? context.fetch(FetchDescriptor<Outcome>())) ?? []
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let next = purchases
            .filter { $0.daysRemaining(now: now) >= 0 }
            .min { $0.returnLastDay < $1.returnLastDay }

        let snapshot = WidgetSnapshot(
            reclaimedThisYearCents: outcomes
                .filter { $0.succeeded && calendar.component(.year, from: $0.date) == year }
                .reduce(0) { $0 + $1.amountCents },
            year: year,
            dropCount: purchases.filter { $0.dropCents > 0 }.count,
            watchedCount: purchases.count,
            nextDeadlineTitle: next?.title,
            nextDeadline: next?.returnLastDay)
        if snapshot != WidgetSnapshot.load() {
            snapshot.save()
            WidgetCenter.shared.reloadAllTimelines()
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
