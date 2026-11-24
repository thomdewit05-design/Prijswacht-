import { adapter as amazon } from "./amazon.ts";
import { adapter as bol } from "./bol.ts";
import { adapter as coolblue } from "./coolblue.ts";
import { adapter as mediamarkt } from "./mediamarkt.ts";
import { AdapterError, type Adapter, type FailureReason, type Offer, type PageFetcher } from "./types.ts";
import { adapter as zalando } from "./zalando.ts";

export const adapters: Adapter[] = [bol, coolblue, mediamarkt, amazon, zalando];

export function normalizeHost(host: string): string {
  const lower = host.toLowerCase();
  return lower.startsWith("www.") ? lower.slice(4) : lower;
}

export function adapterFor(url: string, list: Adapter[] = adapters): Adapter | null {
  let host: string;
  try {
    host = normalizeHost(new URL(url).hostname);
  } catch {
    return null;
  }
  return (
    list.find((adapter) => adapter.domains.some((domain) => host === domain || host.endsWith(`.${domain}`))) ?? null
  );
}

export type FetchResult =
  | { ok: true; shopId: string; offer: Offer }
  | { ok: false; shopId: string | null; reason: FailureReason; detail: string };

/**
 * Haalt een aanbieding op zonder ooit te gooien: een kapotte adapter levert
 * een mislukte regel op en raakt de andere winkels niet.
 */
export async function fetchOfferSafely(
  url: string,
  fetcher: PageFetcher,
  list: Adapter[] = adapters,
): Promise<FetchResult> {
  const adapter = adapterFor(url, list);
  if (adapter === null) return { ok: false, shopId: null, reason: "geen-adapter", detail: url };
  try {
    return { ok: true, shopId: adapter.id, offer: await adapter.fetchOffer(url, fetcher) };
  } catch (error) {
    if (error instanceof AdapterError) {
      return { ok: false, shopId: adapter.id, reason: error.reason, detail: error.message };
    }
    const detail = error instanceof Error ? error.message : String(error);
    return { ok: false, shopId: adapter.id, reason: "adapter-fout", detail };
  }
}

export { AdapterError, type Adapter, type FailureReason, type Offer, type PageFetcher };
