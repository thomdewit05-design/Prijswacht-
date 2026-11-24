// Fase 0: de analyse. Beantwoordt poort 1: daalt minstens 1 op de 20
// producten binnen 30 dagen met minstens 10 euro?
//   node study/analyse.ts [--db <pad>] [--drempel 1000]
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { formatEuro } from "../server/adapters/money.ts";
import { daysBetween } from "../server/jobs/daily.ts";
import { StudyDb, type PriceRow } from "./db.ts";
import { option, studyDir } from "./run.ts";

export interface WindowResult {
  days: number;
  /** Producten met minstens twee metingen. */
  products: number;
  /** Producten die bij minstens één koopdatum genoeg daalden. */
  productsWithDrop: number;
  /** Koopdagen (product x dag) met minstens één latere meting. */
  purchaseDays: number;
  /** Koopdagen waarna de prijs binnen het venster genoeg daalde. */
  purchaseDaysWithDrop: number;
  /** Mediaan van de grootste daling per product, alleen de treffers. */
  medianDropCents: number | null;
}

export interface ProductResult {
  url: string;
  shop: string;
  category: string;
  measurements: number;
  /** Grootste daling per venster, in centen. */
  maxDrop: Record<number, number>;
}

export interface Analysis {
  firstDate: string | null;
  lastDate: string | null;
  windows: WindowResult[];
  products: ProductResult[];
}

/**
 * Per product: neem elke dag als fictieve koopdatum en kijk naar de grootste
 * daling binnen het venster daarna. Alleen metingen op voorraad tellen, als
 * koopdag én als lagere prijs.
 */
export function analyse(rows: PriceRow[], thresholdCents = 1000, windows = [14, 30]): Analysis {
  const byProduct = new Map<string, PriceRow[]>();
  for (const row of rows) byProduct.set(row.url, [...(byProduct.get(row.url) ?? []), row]);

  const dates = rows.map((row) => row.date).sort();
  const results: WindowResult[] = windows.map((days) => ({
    days, products: 0, productsWithDrop: 0, purchaseDays: 0, purchaseDaysWithDrop: 0, medianDropCents: null,
  }));
  const hitDrops: number[][] = windows.map(() => []);
  const products: ProductResult[] = [];

  for (const [url, series] of byProduct) {
    const inStock = series.filter((row) => row.inStock).sort((a, b) => a.date.localeCompare(b.date));
    const first = series[0];
    if (first === undefined || inStock.length < 2) continue;
    const product: ProductResult = { url, shop: first.shop, category: first.category, measurements: inStock.length, maxDrop: {} };

    windows.forEach((days, windowIndex) => {
      const result = results[windowIndex]!;
      let maxDrop = 0;
      inStock.forEach((bought, index) => {
        const later = inStock.slice(index + 1).filter((row) => daysBetween(bought.date, row.date) <= days);
        if (later.length === 0) return;
        const drop = Math.max(0, bought.priceCents - Math.min(...later.map((row) => row.priceCents)));
        result.purchaseDays += 1;
        if (drop >= thresholdCents) result.purchaseDaysWithDrop += 1;
        maxDrop = Math.max(maxDrop, drop);
      });
      result.products += 1;
      if (maxDrop >= thresholdCents) {
        result.productsWithDrop += 1;
        hitDrops[windowIndex]!.push(maxDrop);
      }
      product.maxDrop[days] = maxDrop;
    });
    products.push(product);
  }

  results.forEach((result, index) => {
    const sorted = hitDrops[index]!.sort((a, b) => a - b);
    result.medianDropCents = sorted.length === 0 ? null : sorted[Math.floor((sorted.length - 1) / 2)]!;
  });
  return { firstDate: dates[0] ?? null, lastDate: dates.at(-1) ?? null, windows: results, products };
}

const percent = (part: number, total: number): string =>
  total === 0 ? "n.v.t." : `${((part / total) * 100).toFixed(1).replace(".", ",")}%`;

export function report(analysis: Analysis, thresholdCents: number): string {
  if (analysis.firstDate === null || analysis.lastDate === null) return "Nog geen metingen.";
  const span = daysBetween(analysis.firstDate, analysis.lastDate) + 1;
  const lines = [
    `Metingen van ${analysis.firstDate} tot en met ${analysis.lastDate} (${span} dagen).`,
    `Drempel: daling van minstens ${formatEuro(thresholdCents)}.`,
    "",
  ];
  for (const window of analysis.windows) {
    lines.push(
      `Binnen ${window.days} dagen na aankoop:`,
      `  producten met een daling:   ${window.productsWithDrop} van ${window.products} (${percent(window.productsWithDrop, window.products)})`,
      `  koopdagen met een daling:   ${window.purchaseDaysWithDrop} van ${window.purchaseDays} (${percent(window.purchaseDaysWithDrop, window.purchaseDays)})`,
      `  mediane daling bij treffer: ${window.medianDropCents === null ? "n.v.t." : formatEuro(window.medianDropCents)}`,
      "",
    );
    if (span <= window.days) {
      lines.push(`  Let op: er zijn pas ${span} dagen gemeten; dit venster is nog niet vol.`, "");
    }
  }

  const widest = analysis.windows.at(-1);
  if (widest !== undefined) {
    const groups: Array<[string, (product: ProductResult) => string]> = [
      ["Per winkel", (product) => product.shop],
      ["Per categorie", (product) => product.category || "(geen)"],
    ];
    for (const [title, keyOf] of groups) {
      lines.push(`${title} (binnen ${widest.days} dagen):`);
      const keys = [...new Set(analysis.products.map(keyOf))].sort();
      for (const key of keys) {
        const group = analysis.products.filter((product) => keyOf(product) === key);
        const hits = group.filter((product) => (product.maxDrop[widest.days] ?? 0) >= thresholdCents).length;
        lines.push(`  ${key.padEnd(18)} ${hits} van ${group.length} (${percent(hits, group.length)})`);
      }
      lines.push("");
    }

    const passed = widest.products > 0 && widest.productsWithDrop * 20 >= widest.products;
    lines.push(
      `Poort 1 (minstens 1 op de 20 producten binnen ${widest.days} dagen): ${passed ? "GEHAALD" : "NIET GEHAALD"}.`,
      "Het aandeel koopdagen is de eerlijkste schatting van de trefkans voor een gebruiker:",
      "het aandeel producten telt een product al mee als het na één van alle mogelijke koopdagen daalde.",
    );
  }
  return lines.join("\n");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const threshold = Number.parseInt(option("--drempel", "1000"), 10);
  const db = new StudyDb(option("--db", join(studyDir, "prijsstudie.sqlite")));
  console.log(report(analyse(db.prices(), threshold), threshold));
  db.close();
}
