import Foundation
import XCTest
@testable import PrijswachtCore

final class ReceiptParserTests: XCTestCase {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar
    }

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testOrderConfirmation() {
        let result = ReceiptParser.parse(lines: [
            "Voorbeeldwinkel", "Bedankt voor je bestelling", "Besteldatum: 20-11-2026",
            "Koptelefoon X  1 x  299,00", "Subtotaal  299,00", "Verzendkosten  0,00",
            "BTW 21%  51,89", "Totaal  € 299,00",
        ], calendar: calendar)
        XCTAssertEqual(result.totalCents, 29_900)
        XCTAssertEqual(result.date, date(2026, 11, 20))
        XCTAssertEqual(result.shopName, "Voorbeeldwinkel")
    }

    func testTotalOnNextLineAndAfterDiscount() {
        let result = ReceiptParser.parse(lines: [
            "KASSABON", "Laptop 1.299,00", "Totaal", "1.299,00", "Korting -100,00",
            "Te betalen", "EUR 1.199,00", "Pin 1.199,00", "24 november 2026 14:32",
        ], calendar: calendar)
        XCTAssertEqual(result.totalCents, 119_900)
        XCTAssertEqual(result.date, date(2026, 11, 24))
    }

    func testFallsBackToLargestAmount() {
        let result = ReceiptParser.parse(lines: ["Stofzuiger 449.00", "Zakken 12.95", "2026-11-03"], calendar: calendar)
        XCTAssertEqual(result.totalCents, 44_900)
        XCTAssertEqual(result.date, date(2026, 11, 3))
    }

    func testDateFormats() {
        XCTAssertEqual(ReceiptParser.date(in: ["Datum 3/1/26"], calendar: calendar), date(2026, 1, 3))
        XCTAssertEqual(ReceiptParser.date(in: ["05.12.2026"], calendar: calendar), date(2026, 12, 5))
        XCTAssertEqual(ReceiptParser.date(in: ["7 mrt. 2027"], calendar: calendar), date(2027, 3, 7))
        XCTAssertNil(ReceiptParser.date(in: ["31-02-2026"], calendar: calendar))
        XCTAssertNil(ReceiptParser.date(in: ["Artikel 123456789"], calendar: calendar))
    }

    func testAmountsIgnoreOtherNumbers() {
        XCTAssertEqual(ReceiptParser.amounts(in: "Bestelnummer 1234567890"), [])
        XCTAssertEqual(ReceiptParser.amounts(in: "2 x 19,99 = 39,98"), [1999, 3998])
        XCTAssertEqual(ReceiptParser.amounts(in: "EAN 8712345678906 € 1 299,00"), [129_900])
        XCTAssertEqual(ReceiptParser.amounts(in: "20-11-2026"), [])
    }

    func testEmptyInput() {
        XCTAssertEqual(ReceiptParser.parse(lines: [], calendar: calendar), .init(totalCents: nil, date: nil, shopName: nil))
    }
}
