import assert from "node:assert/strict";
import { test } from "node:test";
import { analyse, report } from "./analyse.ts";
import { parseProducts } from "./csv.ts";
import { StudyDb, type PriceRow } from "./db.ts";
import { runStudy } from "./run.ts";

const row = (url: string, date: string, priceCents: number, extra: Partial<PriceRow> = {}): PriceRow => ({
  date, shop: "winkel", url, ean: null, category: "laptop", priceCents, inStock: true, ...extra,
});

test("products.csv: kolommen, puntkomma's, aanhalingstekens en fouten", () => {
  const { rows, problems } = parseProducts(
    "﻿shop,url,ean,categorie\n" +
      "Bol,https://www.bol.com/p/1,8712345678906,koptelefoon\n" +
      'coolblue;"https://www.coolblue.nl/p/1,2";;"tv, groot"\n' +
      "bol,geen-link,,x\n" +
      "bol,https://www.bol.com/p/1,,dubbel\n",
  );
  assert.deepEqual(rows, [
    { shop: "bol", url: "https://www.bol.com/p/1", ean: "8712345678906", category: "koptelefoon" },
    { shop: "coolblue", url: "https://www.coolblue.nl/p/1,2", ean: null, category: "tv, groot" },
  ]);
  assert.equal(problems.length, 2);
  assert.equal(parseProducts("naam,link\nx,y").rows.length, 0);
});

test("analyse: grootste daling binnen het venster na elke koopdag", () => {
  const rows = [
    // Daalt €50 op dag 10: treffer binnen 14 en 30 dagen.
    row("a", "2026-11-20", 89900), row("a", "2026-11-25", 89900), row("a", "2026-11-30", 84900),
    // Daalt €20 pas na 20 dagen: alleen een treffer binnen 30 dagen.
    row("b", "2026-11-20", 50000), row("b", "2026-11-22", 50000), row("b", "2026-12-12", 48000),
    // Stijgt alleen maar.
    row("c", "2026-11-20", 10000), row("c", "2026-11-30", 12000),
    // Daalt €5: onder de drempel.
    row("d", "2026-11-20", 10000), row("d", "2026-11-30", 9500),
    // Lagere prijs alleen terwijl het niet op voorraad is: telt niet.
    row("e", "2026-11-20", 30000), row("e", "2026-11-25", 20000, { inStock: false }), row("e", "2026-11-30", 30000),
    // Eén meting: doet niet mee.
    row("f", "2026-11-20", 99900),
  ];
  const result = analyse(rows, 1000);
  const [two, four] = result.windows;
  assert.deepEqual([two?.products, two?.productsWithDrop], [5, 1]);
  assert.deepEqual([four?.products, four?.productsWithDrop], [5, 2]);
  assert.equal(two?.medianDropCents, 5000);
  // Koopdagen met een latere meting binnen 14 dagen: a 2, b 1, c 1, d 1, e 1.
  assert.deepEqual([two?.purchaseDays, two?.purchaseDaysWithDrop], [6, 2]);
  assert.equal(result.products.find((product) => product.url === "b")?.maxDrop[30], 2000);
  assert.equal(result.products.find((product) => product.url === "e")?.maxDrop[30], 0);

  const text = report(result, 1000);
  assert.match(text, /producten met een daling: {3}2 van 5 \(40,0%\)/);
  assert.match(text, /Poort 1 .*: GEHAALD/);
  assert.match(report(analyse(rows.filter((r) => r.url === "c" || r.url === "d"), 1000), 1000), /NIET GEHAALD/);
  assert.equal(report(analyse([], 1000), 1000), "Nog geen metingen.");
});

test("meting: slaat prijzen op, logt fouten en gaat door", async () => {
  const db = new StudyDb(":memory:");
  const html = (price: string, ean: string) =>
    `<script type="application/ld+json">{"@type":"Product","gtin13":"${ean}","offers":{"price":"${price}","priceCurrency":"EUR"}}</script>`;
  const pages: Record<string, string> = {
    "https://www.bol.com/p/1": html("261.00", "8712345678906"),
    "https://www.bol.com/p/2": "<html>geen gegevens</html>",
    "https://www.bol.com/p/3": html("99.00", "1111111111111"),
    "https://www.coolblue.nl/p/1": html("899.00", "2222222222222"),
  };
  const products = [
    { shop: "bol", url: "https://www.bol.com/p/1", ean: "8712345678906", category: "koptelefoon" },
    { shop: "bol", url: "https://www.bol.com/p/2", ean: null, category: "tv" },
    { shop: "bol", url: "https://www.bol.com/p/3", ean: "9999999999999", category: "tv" },
    { shop: "bol", url: "https://www.bol.com/p/weg", ean: null, category: "tv" },
    { shop: "coolblue", url: "https://www.coolblue.nl/p/1", ean: null, category: "laptop" },
    { shop: "onbekend", url: "https://onbekend.example/p/1", ean: null, category: "x" },
  ];
  const fetcher = {
    getHtml: async (url: string) => {
      const found = pages[url];
      if (found === undefined) throw new Error("verbinding verbroken");
      return found;
    },
  };

  const first = await runStudy({ products, db, fetcher, date: "2026-11-27" });
  assert.deepEqual(first, { saved: 2, failed: 4, skipped: 0 });
  assert.deepEqual(
    db.prices().map((price) => [price.url, price.priceCents, price.ean]),
    [["https://www.bol.com/p/1", 26100, "8712345678906"], ["https://www.coolblue.nl/p/1", 89900, "2222222222222"]],
  );

  // Dezelfde dag opnieuw: wat er al is wordt niet nog eens opgehaald.
  const again = await runStudy({ products, db, fetcher, date: "2026-11-27" });
  assert.deepEqual([again.saved, again.skipped], [0, 2]);
  const nextDay = await runStudy({ products, db, fetcher, date: "2026-11-28" });
  assert.equal(nextDay.saved, 2);
  assert.equal(db.prices().length, 4);
  db.close();
});
