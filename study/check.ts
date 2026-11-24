// Controleert per winkel of de studie kan werken: mag de pagina volgens
// robots.txt worden opgehaald, en staat er een leesbare prijs in JSON-LD?
//   PRIJSWACHT_CONTACT=mailto:jij@voorbeeld.nl node study/check.ts [--per-winkel 2]
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { PoliteFetcher } from "../server/adapters/http.ts";
import { fetchOfferSafely } from "../server/adapters/index.ts";
import { formatEuro } from "../server/adapters/money.ts";
import { parseProducts } from "./csv.ts";
import { contactOrExit, option, studyDir } from "./run.ts";

const contact = contactOrExit();
const perShop = Number.parseInt(option("--per-winkel", "2"), 10);
const { rows, problems } = parseProducts(readFileSync(option("--products", join(studyDir, "products.csv")), "utf8"));
for (const problem of problems) console.warn(problem);

const fetcher = new PoliteFetcher({ userAgent: `PrijswachtStudie/0.1 (+${contact})` });
const shops = [...new Set(rows.map((row) => row.shop))];

await Promise.all(
  shops.map(async (shop) => {
    for (const row of rows.filter((candidate) => candidate.shop === shop).slice(0, perShop)) {
      const result = await fetchOfferSafely(row.url, fetcher);
      const verdict = result.ok
        ? `OK      ${formatEuro(result.offer.price)}  ean ${result.offer.ean ?? "onbekend"}  ${result.offer.inStock ? "op voorraad" : "niet op voorraad"}  ${result.offer.title ?? ""}`
        : `MISLUKT ${result.reason}`;
      console.log(`${shop.padEnd(12)} ${verdict}\n${"".padEnd(12)} ${row.url}`);
    }
  }),
);
console.log("\nMISLUKT robots-verbiedt: deze winkel wil niet dat je pagina's ophaalt; gebruik een productfeed.");
console.log("MISLUKT geen-gestructureerde-gegevens of geen-product: deze winkel heeft een eigen adapter nodig.");
