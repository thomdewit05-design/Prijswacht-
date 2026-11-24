import Foundation
import XCTest
@testable import PrijswachtCore

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
    return calendar
}

private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

final class MoneyTests: XCTestCase {
    func testFormatting() {
        XCTAssertEqual(Euro.string(3800), "€38")
        XCTAssertEqual(Euro.string(3850), "€38,50")
        XCTAssertEqual(Euro.string(3805), "€38,05")
        XCTAssertEqual(Euro.string(129_900), "€1.299")
        XCTAssertEqual(Euro.string(1_234_567_89), "€1.234.567,89")
        XCTAssertEqual(Euro.string(-500), "-€5")
        XCTAssertEqual(Euro.string(0), "€0")
    }

    func testParsing() {
        XCTAssertEqual(Euro.parse("38"), 3800)
        XCTAssertEqual(Euro.parse("38,5"), 3850)
        XCTAssertEqual(Euro.parse("€ 38,50"), 3850)
        XCTAssertEqual(Euro.parse("1.299,00"), 129_900)
        XCTAssertEqual(Euro.parse("1,299.00"), 129_900)
        XCTAssertEqual(Euro.parse("1299.00"), 129_900)
        XCTAssertEqual(Euro.parse("1.299"), 129_900)
        XCTAssertEqual(Euro.parse("899,-"), 89_900)
        XCTAssertNil(Euro.parse("gratis"))
        XCTAssertNil(Euro.parse(""))
    }

    func testParsingJSONValues() {
        XCTAssertEqual(Euro.parse(json: "899.00"), 89_900)
        XCTAssertEqual(Euro.parse(json: NSNumber(value: 38.1)), 3810)
        XCTAssertEqual(Euro.parse(json: NSNumber(value: 899)), 89_900)
        XCTAssertEqual(Euro.parse(json: NSNumber(value: 19.99)), 1999)
        XCTAssertNil(Euro.parse(json: nil))
    }
}

final class ShopDirectoryTests: XCTestCase {
    let directory = ShopDirectory(shops: [
        ShopProfile(id: "bol", name: "bol", domains: ["bol.com"], returnDays: 30),
        ShopProfile(id: "amazon-nl", name: "Amazon.nl", domains: ["amazon.nl"]),
    ])

    func testMatchesHostAndSubdomains() {
        XCTAssertEqual(directory.shop(for: URL(string: "https://www.bol.com/nl/p/x/1/")!)?.id, "bol")
        XCTAssertEqual(directory.shop(for: URL(string: "https://m.bol.com/p/1")!)?.id, "bol")
        XCTAssertNil(directory.shop(for: URL(string: "https://nietbol.com/p/1")!))
        XCTAssertNil(directory.shop(for: URL(string: "https://amazon.de/dp/1")!))
    }

    func testUnknownShopGetsLegalCoolingOff() {
        let shop = directory.shopOrUnknown(for: URL(string: "https://www.Voorbeeld.nl/p")!)
        XCTAssertEqual(shop.name, "voorbeeld.nl")
        XCTAssertEqual(shop.returnDays, 14)
        XCTAssertNil(shop.returnCostCents)
        XCTAssertFalse(shop.verified)
    }

    func testDecodesJSON() throws {
        let json = """
        [{"id":"x","name":"X","domains":["x.nl"],"country":"NL","returnDays":14,
          "returnCostCents":null,"contactURL":"https://x.nl/contact","contactEmail":null,
          "priceGuarantee":false,"verified":false}]
        """
        let decoded = try ShopDirectory(jsonData: Data(json.utf8))
        XCTAssertEqual(decoded.shops.first?.contactURL?.host, "x.nl")
    }
}

final class ReturnWindowTests: XCTestCase {
    func testCountsFromDeliveryDate() {
        let last = ReturnWindow.lastDay(
            purchaseDate: day(2026, 11, 20), deliveryDate: day(2026, 11, 22, hour: 17),
            returnDays: 14, calendar: utc)
        XCTAssertEqual(last, utc.startOfDay(for: day(2026, 12, 6)))
    }

    func testFallsBackToPurchaseDate() {
        let last = ReturnWindow.lastDay(
            purchaseDate: day(2026, 11, 20), deliveryDate: nil, returnDays: 30, calendar: utc)
        XCTAssertEqual(last, utc.startOfDay(for: day(2026, 12, 20)))
    }

    func testDaysRemaining() {
        let last = utc.startOfDay(for: day(2026, 12, 6))
        XCTAssertEqual(ReturnWindow.daysRemaining(lastDay: last, now: day(2026, 11, 30, hour: 23), calendar: utc), 6)
        XCTAssertEqual(ReturnWindow.daysRemaining(lastDay: last, now: day(2026, 12, 6, hour: 8), calendar: utc), 0)
        XCTAssertEqual(ReturnWindow.daysRemaining(lastDay: last, now: day(2026, 12, 7, hour: 1), calendar: utc), -1)
        XCTAssertTrue(ReturnWindow.isOpen(lastDay: last, now: day(2026, 12, 6, hour: 23), calendar: utc))
        XCTAssertFalse(ReturnWindow.isOpen(lastDay: last, now: day(2026, 12, 7), calendar: utc))
    }

    func testSurvivesDaylightSavingChange() {
        // De klok gaat op 25 oktober 2026 een uur terug.
        let last = ReturnWindow.lastDay(
            purchaseDate: day(2026, 10, 20), deliveryDate: nil, returnDays: 14, calendar: utc)
        XCTAssertEqual(last, utc.startOfDay(for: day(2026, 11, 3)))
        XCTAssertEqual(ReturnWindow.daysRemaining(lastDay: last, now: day(2026, 10, 20), calendar: utc), 14)
    }

    func testReminderThreeDaysBeforeAtNine() {
        let last = utc.startOfDay(for: day(2026, 12, 6))
        XCTAssertEqual(
            ReturnWindow.reminderDate(lastDay: last, now: day(2026, 11, 25), calendar: utc),
            day(2026, 12, 3, hour: 9))
        XCTAssertNil(ReturnWindow.reminderDate(lastDay: last, now: day(2026, 12, 4), calendar: utc))
    }
}

final class RouteAdvisorTests: XCTestCase {
    func shop(returnCost: Cents? = 695, guarantee: Bool = false) -> ShopProfile {
        ShopProfile(id: "s", name: "Winkel", domains: ["s.nl"], returnCostCents: returnCost, priceGuarantee: guarantee)
    }

    func input(
        paid: Cents = 29_900, same: Cents? = 26_100, other: Cents? = nil,
        shop: ShopProfile? = nil, days: Int = 6, threshold: Cents = 1000, refused: Set<Route> = []
    ) -> RouteInput {
        RouteInput(
            paidCents: paid, sameShopCents: same, otherShopCents: other,
            shop: shop ?? self.shop(), daysRemaining: days, thresholdCents: threshold, refused: refused)
    }

    func testAskDifferenceComesFirstWithFullAmount() {
        let options = RouteAdvisor.options(for: input())
        XCTAssertEqual(options.map(\.route), [.askDifference, .returnAndReorder])
        XCTAssertEqual(options[0].netCents, 3800)
        XCTAssertTrue(options[0].recommended)
    }

    func testReturnAndReorderIsNetOfReturnCosts() {
        let option = RouteAdvisor.options(for: input())[1]
        XCTAssertEqual(option.grossCents, 3800)
        XCTAssertEqual(option.netCents, 3105)
        XCTAssertTrue(option.recommended)
    }

    func testRefusedRouteOneMovesRouteTwoUp() {
        let best = RouteAdvisor.best(for: input(refused: [.askDifference]))
        XCTAssertEqual(best?.route, .returnAndReorder)
        XCTAssertEqual(best?.netCents, 3105)
    }

    func testReturnNotRecommendedBelowThreshold() {
        // €15 verschil, €6,95 retourkosten: netto €8,05, onder de drempel van €10.
        let option = RouteAdvisor.options(for: input(same: 28_400)).last
        XCTAssertEqual(option?.route, .returnAndReorder)
        XCTAssertEqual(option?.netCents, 805)
        XCTAssertEqual(option?.recommended, false)
    }

    func testUnknownReturnCostsGiveNoNetAmount() {
        let option = RouteAdvisor.options(for: input(shop: shop(returnCost: nil))).last
        XCTAssertNil(option?.netCents)
        XCTAssertEqual(option?.recommended, false)
    }

    func testExpiredWindowLeavesOnlyAsking() {
        XCTAssertEqual(RouteAdvisor.options(for: input(days: -1)).map(\.route), [.askDifference])
    }

    func testNoOptionsWithoutDrop() {
        XCTAssertTrue(RouteAdvisor.options(for: input(same: 29_900)).isEmpty)
        XCTAssertTrue(RouteAdvisor.options(for: input(same: 31_000)).isEmpty)
        XCTAssertTrue(RouteAdvisor.options(for: input(same: nil)).isEmpty)
    }

    func testPriceGuaranteeOnlyWhenShopOffersItAndOtherIsCheaper() {
        XCTAssertFalse(RouteAdvisor.options(for: input(other: 25_000)).contains { $0.route == .priceGuarantee })
        let options = RouteAdvisor.options(for: input(other: 25_000, shop: shop(guarantee: true)))
        XCTAssertEqual(options.map(\.route), [.askDifference, .priceGuarantee, .returnAndReorder])
        XCTAssertEqual(options[1].netCents, 4900)
        // Andere winkel niet goedkoper dan de eigen winkel: geen route 3.
        XCTAssertFalse(RouteAdvisor.options(for: input(other: 27_000, shop: shop(guarantee: true)))
            .contains { $0.route == .priceGuarantee })
    }
}

final class DropDetectorTests: XCTestCase {
    let t0 = day(2026, 11, 27, hour: 6)

    func evaluate(_ offer: Offer, pending: PendingDrop? = nil, after seconds: TimeInterval = 0) -> DropDecision {
        DropDetector.evaluate(
            offer: offer, paidCents: 29_900, thresholdCents: 1000,
            expectedSeller: "Coolblue", pending: pending, now: t0.addingTimeInterval(seconds))
    }

    func testFirstSightingIsOnlyPending() {
        XCTAssertEqual(
            evaluate(Offer(priceCents: 26_100)),
            .pending(PendingDrop(priceCents: 26_100, firstSeenAt: t0)))
    }

    func testConfirmedAfterAnHour() {
        let pending = PendingDrop(priceCents: 26_100, firstSeenAt: t0)
        XCTAssertEqual(
            evaluate(Offer(priceCents: 26_100), pending: pending, after: 3600),
            .confirmed(priceCents: 26_100, dropCents: 3800))
    }

    func testSecondCheckTooEarlyStaysPending() {
        let pending = PendingDrop(priceCents: 26_100, firstSeenAt: t0)
        XCTAssertEqual(evaluate(Offer(priceCents: 26_100), pending: pending, after: 1800), .pending(pending))
    }

    func testReportsTheSmallerOfTwoDrops() {
        let pending = PendingDrop(priceCents: 25_000, firstSeenAt: t0)
        XCTAssertEqual(
            evaluate(Offer(priceCents: 26_100), pending: pending, after: 7200),
            .confirmed(priceCents: 26_100, dropCents: 3800))
    }

    func testPriceBackUpCancelsPendingDrop() {
        let pending = PendingDrop(priceCents: 26_100, firstSeenAt: t0)
        XCTAssertEqual(evaluate(Offer(priceCents: 29_900), pending: pending, after: 7200), DropDecision.none)
    }

    func testBelowThresholdIsNoDrop() {
        XCTAssertEqual(evaluate(Offer(priceCents: 29_000)), DropDecision.none)
    }

    func testFakeDropsAreIgnored() {
        XCTAssertEqual(evaluate(Offer(priceCents: 20_000, inStock: false)), DropDecision.none)
        XCTAssertEqual(evaluate(Offer(priceCents: 20_000, isNew: false)), DropDecision.none)
        XCTAssertEqual(evaluate(Offer(priceCents: 20_000, seller: "Tweedehands BV")), DropDecision.none)
        XCTAssertEqual(evaluate(Offer(priceCents: 20_000, currency: "USD")), DropDecision.none)
        XCTAssertEqual(evaluate(Offer(priceCents: 0)), DropDecision.none)
    }

    func testSameSellerInDifferentSpellingCounts() {
        XCTAssertNotEqual(evaluate(Offer(priceCents: 26_100, seller: "Coolblue.nl")), DropDecision.none)
        XCTAssertNotEqual(evaluate(Offer(priceCents: 26_100, seller: "Coolblue B.V.")), DropDecision.none)
        XCTAssertNotEqual(evaluate(Offer(priceCents: 26_100, seller: nil)), DropDecision.none)
    }
}

final class MessageComposerTests: XCTestCase {
    let context = MessageComposer.Context(
        productTitle: "Sony WH-1000XM5", shopName: "Coolblue", orderNumber: "12345678",
        purchaseDate: day(2026, 11, 20), paidCents: 29_900, newCents: 26_100,
        productURL: URL(string: "https://www.coolblue.nl/product/1"), observedAt: day(2026, 11, 28))

    func testAskDifferenceMentionsEverythingTheShopNeeds() {
        let message = MessageComposer.message(for: .askDifference, context: context, calendar: utc)
        XCTAssertEqual(message.subject, "Vraag over prijsverschil (bestelling 12345678)")
        for part in ["Sony WH-1000XM5", "20 november 2026", "€299", "€261", "€38", "Bestelnummer: 12345678", "coolblue.nl/product/1"] {
            XCTAssertTrue(message.body.contains(part), "mist: \(part)")
        }
        XCTAssertFalse(message.body.contains("\n\n\n"))
    }

    func testWithoutOrderNumberLeavesNoGap() {
        var bare = context
        bare.orderNumber = nil
        bare.productURL = nil
        for route in Route.allCases {
            let message = MessageComposer.message(for: route, context: bare, calendar: utc)
            XCTAssertFalse(message.body.contains("Bestelnummer"))
            XCTAssertFalse(message.body.contains("\n\n\n"))
            XCTAssertFalse(message.subject.contains("bestelling"))
        }
    }

    func testNoMessageClaimsARightToTheDifference() {
        for route in Route.allCases {
            let body = MessageComposer.message(for: route, context: context, calendar: utc).body.lowercased()
            XCTAssertFalse(body.contains("recht op"))
            XCTAssertFalse(body.contains("verplicht"))
        }
    }

    func testPriceGuaranteeNamesTheOtherShop() {
        var other = context
        other.otherShopName = "MediaMarkt"
        let message = MessageComposer.message(for: .priceGuarantee, context: other, calendar: utc)
        XCTAssertTrue(message.body.contains("Bij MediaMarkt"))
    }
}

final class PlanTests: XCTestCase {
    func testFreeTierLimits() {
        XCTAssertTrue(FreeTier.canAddPurchase(activeCount: 2, isPlus: false))
        XCTAssertFalse(FreeTier.canAddPurchase(activeCount: 3, isPlus: false))
        XCTAssertTrue(FreeTier.canAddPurchase(activeCount: 30, isPlus: true))
        XCTAssertTrue(FreeTier.canOpenRoute(completedOutcomes: 0, isPlus: false))
        XCTAssertFalse(FreeTier.canOpenRoute(completedOutcomes: 1, isPlus: false))
    }

    func testSuccessRateNeedsEnoughAnswers() {
        XCTAssertNil(SuccessRate(succeeded: 2, total: 2).percentage)
        XCTAssertEqual(SuccessRate(succeeded: 2, total: 3).percentage, 67)
    }
}
