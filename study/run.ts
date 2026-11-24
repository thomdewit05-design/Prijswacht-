// Fase 0: de dagelijkse meting van de prijsstudie.
//   PRIJSWACHT_CONTACT=mailto:jij@voorbeeld.nl node study/run.ts
// Opties: --products <pad> (standaard study/products.csv), --db <pad>.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { PoliteFetcher } from "../server/adapters/http.ts";
import { adapterFor, fetchOfferSafely } from "../server/adapters/index.ts";
import type { PageFetcher } from "../server/adapters/types.ts";
import { dutchDate } from "../server/jobs/daily.ts";
import { parseProducts, type ProductRow } from "./csv.ts";
import { StudyDb } from "./db.ts";

export interface RunSummary {
  saved: number;
  failed: number;
  skipped: number;
}

/**
 * Meet alle producten één keer. Winkels lopen naast elkaar, producten van
 * dezelfde winkel na elkaar (de fetcher wacht vijf seconden per winkel).
 * Een mislukte regel wordt gelogd; de rest gaat door.
 */
export async function runStudy(options: {
  products: ProductRow[];
  db: StudyDb;
  fetcher: PageFetcher;
  date: string;
  log?: (line: string) => void;
}): Promise<RunSummary> {
  const log = options.log ?? (() => {});
  const summary: RunSummary = { saved: 0, failed: 0, skipped: 0 };
  const byShop = new Map<string, ProductRow[]>();
  for (const row of options.products) byShop.set(row.shop, [...(byShop.get(row.shop) ?? []), row]);

  const fail = (row: ProductRow, reason: string, detail: string): void => {
    summary.failed += 1;
    options.db.saveFailure({ date: options.date, shop: row.shop, url: row.url, reason, detail });
    log(`mislukt [${row.shop}] ${reason}: ${row.url}`);
  };

  await Promise.all(
    [...byShop.values()].map(async (rows) => {
      for (const row of rows) {
        try {
          if (options.db.hasPrice(options.date, row.url)) {
            summary.skipped += 1;
            continue;
          }
          const result = await fetchOfferSafely(row.url, options.fetcher);
          if (!result.ok) {
            fail(row, result.reason, result.detail);
          } else if (row.ean && result.offer.ean && row.ean !== result.offer.ean) {
            fail(row, "ean-verschilt", `lijst ${row.ean}, pagina ${result.offer.ean}`);
          } else if (result.offer.currency !== "EUR" || !result.offer.isNew) {
            fail(row, "geen-nieuwprijs-in-euro", `${result.offer.currency}, nieuw: ${result.offer.isNew}`);
          } else {
            options.db.savePrice({
              date: options.date,
              shop: row.shop,
              url: row.url,
              ean: row.ean ?? result.offer.ean,
              category: row.category,
              priceCents: result.offer.price,
              inStock: result.offer.inStock,
            });
            summary.saved += 1;
          }
        } catch (error) {
          fail(row, "onverwacht", error instanceof Error ? error.message : String(error));
        }
      }
    }),
  );
  return summary;
}

export function option(name: string, fallback: string): string {
  const index = process.argv.indexOf(name);
  return index >= 0 ? (process.argv[index + 1] ?? fallback) : fallback;
}

export function contactOrExit(): string {
  const contact = process.env.PRIJSWACHT_CONTACT;
  if (!contact) {
    console.error("Zet PRIJSWACHT_CONTACT op je contactadres, bijvoorbeeld mailto:jij@voorbeeld.nl.");
    console.error("Dat adres komt in de User-Agent, zodat een winkel je kan bereiken.");
    process.exit(2);
  }
  return contact;
}

export const studyDir = dirname(fileURLToPath(import.meta.url));

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const contact = contactOrExit();
  const { rows, problems } = parseProducts(readFileSync(option("--products", join(studyDir, "products.csv")), "utf8"));
  for (const problem of problems) console.warn(problem);
  for (const row of rows.filter((row) => adapterFor(row.url) === null)) {
    console.warn(`Geen adapter voor ${row.url}; die regel mislukt.`);
  }

  const db = new StudyDb(option("--db", join(studyDir, "prijsstudie.sqlite")));
  const date = dutchDate(Date.now());
  const summary = await runStudy({
    products: rows,
    db,
    fetcher: new PoliteFetcher({ userAgent: `PrijswachtStudie/0.1 (+${contact})` }),
    date,
    log: (line) => console.log(line),
  });
  db.close();
  console.log(`${date}: ${summary.saved} prijzen opgeslagen, ${summary.failed} mislukt, ${summary.skipped} al gemeten.`);
}
