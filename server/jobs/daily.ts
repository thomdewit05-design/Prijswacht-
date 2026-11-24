import { adapters as allAdapters, fetchOfferSafely } from "../adapters/index.ts";
import { formatEuro } from "../adapters/money.ts";
import type { Adapter, PageFetcher } from "../adapters/types.ts";
import { evaluateDrop } from "./detect.ts";
import type { PushSender, Store, Watch } from "./store.ts";

export interface DailyOptions {
  store: Store;
  fetcher: PageFetcher;
  push: PushSender;
  adapters?: Adapter[];
  now?: () => number;
  /** Alleen aankopen met een daling die op de tweede controle wacht. */
  recheckOnly?: boolean;
  log?: (line: string) => void;
}

export interface DailyResult {
  checked: number;
  failed: number;
  alerts: number;
}

const DAY_MS = 24 * 60 * 60 * 1000;

/** JJJJ-MM-DD in Nederlandse tijd. */
export function dutchDate(timestamp: number): string {
  return new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Amsterdam" }).format(new Date(timestamp));
}

export function daysBetween(from: string, to: string): number {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / DAY_MS);
}

/**
 * De dagelijkse prijscontrole. Haalt elke link één keer op, ook als meerdere
 * mensen hetzelfde product bewaken, en stuurt pas een melding na de tweede
 * controle. Een fout bij één product of winkel stopt de rest niet.
 */
export async function runDaily(options: DailyOptions): Promise<DailyResult> {
  const now = options.now ?? Date.now;
  const log = options.log ?? (() => {});
  const result: DailyResult = { checked: 0, failed: 0, alerts: 0 };

  const today = dutchDate(now());
  let watches = await options.store.activeWatches(today);
  if (options.recheckOnly) watches = watches.filter((watch) => watch.pending !== null);

  const byUrl = new Map<string, Watch[]>();
  for (const watch of watches) {
    byUrl.set(watch.url, [...(byUrl.get(watch.url) ?? []), watch]);
  }

  for (const [url, group] of byUrl) {
    try {
      const fetched = await fetchOfferSafely(url, options.fetcher, options.adapters ?? allAdapters);
      const observedAt = now();
      if (!fetched.ok) {
        result.failed += 1;
        log(`mislukt ${url}: ${fetched.detail}`);
        await options.store.recordFailure({ url, shopId: fetched.shopId, reason: fetched.reason, detail: fetched.detail, observedAt });
        continue;
      }
      result.checked += 1;
      await options.store.recordOffer({ url, shopId: fetched.shopId, offer: fetched.offer, observedAt });

      for (const watch of group) {
        // Ander product dan de aankoop (andere variant op dezelfde link):
        // niet vergelijken.
        if (watch.ean && fetched.offer.ean && watch.ean !== fetched.offer.ean) continue;
        result.alerts += await applyOffer(options, watch, fetched.offer, observedAt, today);
      }
    } catch (error) {
      result.failed += 1;
      log(`fout bij ${url}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  return result;
}

async function applyOffer(
  options: DailyOptions,
  watch: Watch,
  offer: Parameters<typeof evaluateDrop>[0]["offer"],
  observedAt: number,
  today: string,
): Promise<number> {
  const decision = evaluateDrop({
    offer,
    paidCents: watch.paidCents,
    thresholdCents: watch.thresholdCents,
    expectedSeller: watch.shopName,
    pending: watch.pending,
    now: observedAt,
  });

  if (decision.kind === "none") {
    await options.store.savePurchaseState(watch.purchaseId, {
      currentCents: offer.price, checkedAt: observedAt, pending: null, confirmedCents: null,
    });
    return 0;
  }
  if (decision.kind === "pending") {
    await options.store.savePurchaseState(watch.purchaseId, {
      currentCents: offer.price, checkedAt: observedAt, pending: decision.pending, confirmedCents: watch.confirmedCents,
    });
    return 0;
  }

  await options.store.savePurchaseState(watch.purchaseId, {
    currentCents: offer.price, checkedAt: observedAt, pending: watch.pending, confirmedCents: decision.priceCents,
  });
  const isNew = await options.store.createAlert({
    purchaseId: watch.purchaseId,
    newCents: decision.priceCents,
    dropCents: decision.dropCents,
    route: "askDifference",
  });
  if (!isNew) return 0;

  const days = daysBetween(today, watch.returnLastDay);
  const body =
    days > 1 ? `Je kunt nog ${days} dagen retourneren. Bekijk de snelste route.`
    : days === 1 ? "Je kunt nog 1 dag retourneren. Bekijk de snelste route."
    : "Vandaag is de laatste dag om te retourneren. Bekijk de snelste route.";
  for (const token of await options.store.deviceTokens(watch.installId)) {
    try {
      await options.push.send(token, {
        title: `${watch.title} is ${formatEuro(decision.dropCents)} goedkoper`,
        body,
        purchaseId: watch.purchaseId,
      });
    } catch (error) {
      (options.log ?? (() => {}))(`push mislukt: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  return 1;
}
