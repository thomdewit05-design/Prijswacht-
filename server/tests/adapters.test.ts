import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { PoliteFetcher } from "../adapters/http.ts";
import { adapterFor, adapters, fetchOfferSafely } from "../adapters/index.ts";
import { parseJsonLdOffer } from "../adapters/jsonld.ts";
import { formatEuro, parseCents } from "../adapters/money.ts";
import { Robots } from "../adapters/robots.ts";
import { jsonLdAdapter } from "../adapters/shared.ts";
import { AdapterError, type Adapter } from "../adapters/types.ts";

const fixtures = join(dirname(fileURLToPath(import.meta.url)), "fixtures");
const page = (json: string): string => `<html><head><script type="application/ld+json">${json}</script></head></html>`;
const reasonOf = (run: () => unknown): string => {
  try {
    run();
  } catch (error) {
    return error instanceof AdapterError ? error.reason : "andere fout";
  }
  return "geen fout";
};

test("bedragen worden gehele centen", () => {
  assert.equal(parseCents("38"), 3800);
  assert.equal(parseCents("38,5"), 3850);
  assert.equal(parseCents("€ 38,50"), 3850);
  assert.equal(parseCents("1.299,00"), 129900);
  assert.equal(parseCents("1,299.00"), 129900);
  assert.equal(parseCents("1299.00"), 129900);
  assert.equal(parseCents(899), 89900);
  assert.equal(parseCents(38.1), 3810);
  assert.equal(parseCents(19.99), 1999);
  assert.equal(parseCents("gratis"), null);
  assert.equal(parseCents(null), null);
  assert.equal(formatEuro(3800), "€38");
  assert.equal(formatEuro(129950), "€1.299,50");
  assert.equal(formatEuro(3805), "€38,05");
});

test("JSON-LD: product in @graph, getal als prijs, niet op voorraad", () => {
  const offer = parseJsonLdOffer(page(`{"@graph":[{"@type":"BreadcrumbList"},
    {"@type":["Product","ItemPage"],"name":"Laptop","gtin":8712345678906,
     "offers":[{"@type":"Offer","price":899,"priceCurrency":"eur","availability":"http://schema.org/OutOfStock"}]}]}`));
  assert.equal(offer.price, 89900);
  assert.equal(offer.ean, "8712345678906");
  assert.equal(offer.currency, "EUR");
  assert.equal(offer.inStock, false);
});

test("JSON-LD: kapot blok wordt overgeslagen", () => {
  const html = `<script type="application/ld+json">{ kapot </script>
    <SCRIPT data-x="1" type='application/ld+json'>{"@type":"Product","name":"X","offers":{"price":"1.299,00"}}</SCRIPT>`;
  assert.equal(parseJsonLdOffer(html).price, 129900);
});

test("JSON-LD: vanaf-prijzen en meerdere prijzen worden geweigerd", () => {
  assert.equal(reasonOf(() => parseJsonLdOffer(page(`{"@type":"Product","offers":{"@type":"AggregateOffer",
    "lowPrice":"499.00","highPrice":"649.00","offerCount":6}}`))), "prijs-niet-eenduidig");
  assert.equal(reasonOf(() => parseJsonLdOffer(page(`{"@type":"Product","offers":[
    {"@type":"Offer","price":"799.00"},{"@type":"Offer","price":"749.00"}]}`))), "prijs-niet-eenduidig");
});

test("JSON-LD: tweedehands naast nieuw telt niet mee", () => {
  const offer = parseJsonLdOffer(page(`{"@type":"Product","offers":[
    {"@type":"Offer","price":"799.00","itemCondition":"https://schema.org/NewCondition"},
    {"@type":"Offer","price":"650.00","itemCondition":"https://schema.org/UsedCondition"}]}`));
  assert.equal(offer.price, 79900);
});

test("JSON-LD: duidelijke redenen bij mislukken", () => {
  assert.equal(reasonOf(() => parseJsonLdOffer("<html></html>")), "geen-gestructureerde-gegevens");
  assert.equal(reasonOf(() => parseJsonLdOffer(page(`{"@type":"Organization"}`))), "geen-product");
  assert.equal(reasonOf(() => parseJsonLdOffer(page(`{"@type":"Product","name":"X"}`))), "geen-aanbieding");
});

test("robots.txt: langste regel wint, eigen groep gaat voor", () => {
  const robots = new Robots(`
    User-agent: *
    Disallow: /checkout
    Disallow: /*?sort=
    Allow: /checkout/help
    Disallow: /*.pdf$

    User-agent: PrijswachtStudie
    Disallow: /
  `);
  assert.equal(robots.allows("Mozilla", "/product/1"), true);
  assert.equal(robots.allows("Mozilla", "/checkout/pay"), false);
  assert.equal(robots.allows("Mozilla", "/checkout/help"), true);
  assert.equal(robots.allows("Mozilla", "/lijst?sort=prijs"), false);
  assert.equal(robots.allows("Mozilla", "/a.pdf"), false);
  assert.equal(robots.allows("Mozilla", "/a.pdf.html"), true);
  assert.equal(robots.allows("PrijswachtStudie/0.1 (+mailto:x@y.nl)", "/product/1"), false);
  assert.equal(new Robots("").allows("x", "/alles"), true);
  assert.equal(new Robots("User-agent: *\nDisallow:").allows("x", "/alles"), true);
});

function fakeSite(pages: Record<string, { status: number; body: string }>) {
  const calls: Array<{ url: string; at: number; agent: string | null }> = [];
  let clock = 0;
  const fetcher = new PoliteFetcher({
    userAgent: "PrijswachtStudie/0.1 (+mailto:test@voorbeeld.example)",
    now: () => clock,
    sleep: async (ms) => {
      clock += ms;
    },
    fetchImpl: (async (input: URL | string | Request, init?: RequestInit) => {
      const url = String(input);
      calls.push({ url, at: clock, agent: new Headers(init?.headers).get("User-Agent") });
      const found = pages[url];
      if (found === undefined) throw new Error("geen verbinding");
      return new Response(found.body, { status: found.status });
    }) as typeof fetch,
  });
  return { fetcher, calls };
}

test("fetcher: vijf seconden tussen verzoeken per winkel, eerlijke User-Agent", async () => {
  const { fetcher, calls } = fakeSite({
    "https://a.example/robots.txt": { status: 200, body: "User-agent: *\nDisallow: /prive" },
    "https://a.example/p/1": { status: 200, body: "een" },
    "https://a.example/p/2": { status: 200, body: "twee" },
    "https://b.example/robots.txt": { status: 404, body: "" },
    "https://b.example/p/1": { status: 200, body: "b" },
  });
  assert.equal(await fetcher.getHtml("https://a.example/p/1"), "een");
  assert.equal(await fetcher.getHtml("https://a.example/p/2"), "twee");
  assert.equal(await fetcher.getHtml("https://b.example/p/1"), "b");

  const a = calls.filter((call) => call.url.startsWith("https://a.example"));
  assert.deepEqual(a.map((call) => call.at), [0, 5000, 10000]);
  assert.equal(a.filter((call) => call.url.endsWith("robots.txt")).length, 1);
  assert.ok(calls.every((call) => call.agent?.includes("mailto:test@voorbeeld.example")));
  // Een andere winkel hoeft niet op de eerste te wachten.
  assert.ok(calls.filter((call) => call.url.startsWith("https://b.example")).every((call) => call.at <= 15000));
});

test("fetcher: robots.txt en fouten", async () => {
  const { fetcher, calls } = fakeSite({
    "https://a.example/robots.txt": { status: 200, body: "User-agent: *\nDisallow: /prive" },
    "https://a.example/weg": { status: 404, body: "" },
    "https://stuk.example/robots.txt": { status: 503, body: "" },
  });
  await assert.rejects(fetcher.getHtml("https://a.example/prive/1"), /robots-verbiedt/);
  assert.equal(calls.some((call) => call.url.includes("/prive")), false);
  await assert.rejects(fetcher.getHtml("https://a.example/weg"), /http-status: 404/);
  // Zonder leesbare robots.txt halen we niets op, en dat heet geen verbod.
  await assert.rejects(fetcher.getHtml("https://stuk.example/p"), /netwerk: robots.txt niet bereikbaar/);
  await assert.rejects(fetcher.getHtml("https://weg.example/p"), /netwerk: robots.txt niet bereikbaar/);
  assert.equal(calls.some((call) => call.url === "https://stuk.example/p"), false);
  assert.throws(() => new PoliteFetcher({ userAgent: "Anoniem/1.0" }), /contactadres/);
});

test("elke winkel heeft een adapter en links komen bij de goede uit", () => {
  assert.deepEqual(adapters.map((adapter) => adapter.id).sort(), ["amazon-nl", "bol", "coolblue", "mediamarkt", "zalando"]);
  assert.equal(adapterFor("https://www.bol.com/nl/nl/p/x/1/")?.id, "bol");
  assert.equal(adapterFor("https://www.coolblue.be/nl/product/1")?.id, "coolblue");
  assert.equal(adapterFor("https://m.zalando.nl/x.html")?.id, "zalando");
  assert.equal(adapterFor("https://www.amazon.de/dp/1"), null);
  assert.equal(adapterFor("https://nietbol.com/p"), null);
  assert.equal(adapterFor("geen link"), null);
});

test("een kapotte adapter raakt de andere niet", async () => {
  const broken: Adapter = {
    id: "kapot", name: "Kapot", domains: ["kapot.example"],
    fetchOffer: async () => {
      throw new TypeError("onverwachte fout in de adapter");
    },
  };
  const working = jsonLdAdapter({ id: "goed", name: "Goed", domains: ["goed.example"] });
  const fetcher = { getHtml: async () => page(`{"@type":"Product","offers":{"price":"10.00"}}`) };
  const list = [broken, working];

  const bad = await fetchOfferSafely("https://kapot.example/p", fetcher, list);
  assert.deepEqual([bad.ok, bad.ok ? "" : bad.reason], [false, "adapter-fout"]);
  const good = await fetchOfferSafely("https://goed.example/p", fetcher, list);
  assert.equal(good.ok && good.offer.price, 1000);
  const none = await fetchOfferSafely("https://onbekend.example/p", fetcher, list);
  assert.equal(none.ok ? "" : none.reason, "geen-adapter");
});

// Opgeslagen voorbeeldpagina's per winkel. Een winkel zonder echte pagina's
// staat als "todo" in de uitvoer, zodat zichtbaar blijft wat nog ontbreekt.
for (const adapter of [...adapters, jsonLdAdapter({ id: "voorbeeld", name: "Voorbeeld", domains: [] })]) {
  const folder = join(fixtures, adapter.id);
  const pages = existsSync(folder) ? readdirSync(folder).filter((name) => name.endsWith(".html")) : [];
  if (pages.length === 0) {
    test(`voorbeeldpagina's ${adapter.id}`, { todo: "nog geen echte pagina's opgeslagen (study/save-fixture.ts)" }, () => {});
    continue;
  }
  for (const name of pages) {
    test(`voorbeeldpagina ${adapter.id}/${name}`, async () => {
      const html = readFileSync(join(folder, name), "utf8");
      const expected = JSON.parse(readFileSync(join(folder, name.replace(/\.html$/, ".expected.json")), "utf8"));
      assert.deepEqual(await adapter.fetchOffer("https://voorbeeld.example/p", { getHtml: async () => html }), expected);
    });
  }
}
