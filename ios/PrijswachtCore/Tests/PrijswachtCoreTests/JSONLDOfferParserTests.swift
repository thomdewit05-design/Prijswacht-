import Foundation
import XCTest
@testable import PrijswachtCore

/// Zelfgemaakte voorbeelden van de vormen die JSON-LD kan hebben. Dit zijn
/// géén opgeslagen pagina's van echte winkels; die horen per winkel bij de
/// adapters op de server.
final class JSONLDOfferParserTests: XCTestCase {
    func page(_ json: String) -> String {
        "<html><head><script type=\"application/ld+json\">\(json)</script></head><body></body></html>"
    }

    func testSimpleProduct() throws {
        let html = page("""
        {"@context":"https://schema.org","@type":"Product","name":" Koptelefoon X ",
         "image":["https://img.example/1.jpg"],"gtin13":"4548736132580",
         "offers":{"@type":"Offer","price":"261.00","priceCurrency":"EUR",
           "availability":"https://schema.org/InStock","itemCondition":"https://schema.org/NewCondition",
           "seller":{"@type":"Organization","name":"Winkel"}}}
        """)
        let offer = try JSONLDOfferParser.parse(html: html).get()
        XCTAssertEqual(offer.title, "Koptelefoon X")
        XCTAssertEqual(offer.ean, "4548736132580")
        XCTAssertEqual(offer.priceCents, 26_100)
        XCTAssertEqual(offer.imageURL?.absoluteString, "https://img.example/1.jpg")
        XCTAssertEqual(offer.seller, "Winkel")
        XCTAssertTrue(offer.inStock)
        XCTAssertTrue(offer.isNew)
    }

    func testProductInsideGraphWithNumericPriceAndOfferArray() throws {
        let html = page("""
        {"@context":"https://schema.org","@graph":[{"@type":"BreadcrumbList"},
          {"@type":["Product","ItemPage"],"name":"Laptop","gtin":8712345678906,
           "offers":[{"@type":"Offer","price":899,"priceCurrency":"EUR","availability":"http://schema.org/OutOfStock"}]}]}
        """)
        let offer = try JSONLDOfferParser.parse(html: html).get()
        XCTAssertEqual(offer.priceCents, 89_900)
        XCTAssertEqual(offer.ean, "8712345678906")
        XCTAssertFalse(offer.inStock)
    }

    func testSkipsBrokenBlocksAndFindsLaterProduct() throws {
        let html = """
        <script type="application/ld+json">{ kapot </script>
        <script>var x = "<script>";</script>
        <SCRIPT data-x="1" type='application/ld+json'>
        {"@type":"Product","name":"Stofzuiger","offers":{"price":"1.299,00","priceCurrency":"EUR"}}
        </SCRIPT>
        """
        XCTAssertEqual(try JSONLDOfferParser.parse(html: html).get().priceCents, 129_900)
    }

    func testFromPriceIsRejected() {
        let html = page("""
        {"@type":"Product","name":"Telefoon","offers":{"@type":"AggregateOffer",
          "lowPrice":"499.00","highPrice":"649.00","offerCount":6,"priceCurrency":"EUR"}}
        """)
        XCTAssertEqual(JSONLDOfferParser.parse(html: html), .failure(.ambiguousPrice))
    }

    func testAggregateWithOneOfferIsAccepted() throws {
        let html = page("""
        {"@type":"Product","name":"Telefoon","offers":{"@type":"AggregateOffer",
          "lowPrice":"499.00","highPrice":"499.00","offerCount":1,"priceCurrency":"EUR"}}
        """)
        XCTAssertEqual(try JSONLDOfferParser.parse(html: html).get().priceCents, 49_900)
    }

    func testUsedOfferNextToNewOneIsIgnored() throws {
        let html = page("""
        {"@type":"Product","name":"Tv","offers":[
          {"@type":"Offer","price":"799.00","priceCurrency":"EUR","itemCondition":"https://schema.org/NewCondition"},
          {"@type":"Offer","price":"650.00","priceCurrency":"EUR","itemCondition":"https://schema.org/UsedCondition"}]}
        """)
        let offer = try JSONLDOfferParser.parse(html: html).get()
        XCTAssertEqual(offer.priceCents, 79_900)
        XCTAssertTrue(offer.isNew)
    }

    func testSeveralNewOffersWithDifferentPricesAreAmbiguous() {
        let html = page("""
        {"@type":"Product","name":"Tv","offers":[
          {"@type":"Offer","price":"799.00","priceCurrency":"EUR"},
          {"@type":"Offer","price":"749.00","priceCurrency":"EUR"}]}
        """)
        XCTAssertEqual(JSONLDOfferParser.parse(html: html), .failure(.ambiguousPrice))
    }

    func testFailures() {
        XCTAssertEqual(JSONLDOfferParser.parse(html: "<html></html>"), .failure(.noStructuredData))
        XCTAssertEqual(JSONLDOfferParser.parse(html: page(#"{"@type":"Organization","name":"X"}"#)), .failure(.noProduct))
        XCTAssertEqual(JSONLDOfferParser.parse(html: page(#"{"@type":"Product","name":"X"}"#)), .failure(.noOffer))
    }
}
