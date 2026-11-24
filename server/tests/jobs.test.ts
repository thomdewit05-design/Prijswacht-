import assert from "node:assert/strict";
import { generateKeyPairSync, verify } from "node:crypto";
import { test } from "node:test";
import { jsonLdAdapter } from "../adapters/shared.ts";
import type { Offer } from "../adapters/types.ts";
import { apnsPayload, apnsToken } from "../jobs/apns.ts";
import { daysBetween, dutchDate, runDaily } from "../jobs/daily.ts";
import { evaluateDrop, sellerMatches, type PendingDrop } from "../jobs/detect.ts";
import type { NewAlert, PurchaseState, PushMessage, Store, Watch } from "../jobs/store.ts";
import { parseSyncRequest } from "../jobs/sync-request.ts";

const HOUR = 60 * 60 * 1000;
const T0 = Date.parse("2026-11-27T05:00:00Z");

const offer = (price: number, extra: Partial<Offer> = {}): Offer => ({
  ean: null, title: "Koptelefoon", imageUrl: null, price, currency: "EUR", inStock: true, isNew: true, seller: null, ...extra,
});

const decide = (o: Offer, pending: PendingDrop | null = null, after = 0) =>
  evaluateDrop({ offer: o, paidCents: 29900, thresholdCents: 1000, expectedSeller: "Coolblue", pending, now: T0 + after });

test("daling: eerst wachten, na een uur bevestigd", () => {
  assert.deepEqual(decide(offer(26100)), { kind: "pending", pending: { priceCents: 26100, firstSeenAt: T0 } });
  const pending = { priceCents: 26100, firstSeenAt: T0 };
  assert.deepEqual(decide(offer(26100), pending, HOUR / 2), { kind: "pending", pending });
  assert.deepEqual(decide(offer(26100), pending, HOUR), { kind: "confirmed", priceCents: 26100, dropCents: 3800 });
  // De voorzichtigste van twee metingen wordt gemeld.
  assert.deepEqual(decide(offer(26100), { priceCents: 25000, firstSeenAt: T0 }, 2 * HOUR),
    { kind: "confirmed", priceCents: 26100, dropCents: 3800 });
});

test("daling: nepdalingen tellen niet", () => {
  for (const fake of [
    offer(29000), offer(29900), offer(20000, { inStock: false }), offer(20000, { isNew: false }),
    offer(20000, { seller: "Tweedehands BV" }), offer(20000, { currency: "USD" }), offer(0),
  ]) {
    assert.deepEqual(decide(fake), { kind: "none" });
  }
  assert.equal(sellerMatches("Coolblue B.V.", "Coolblue"), true);
  assert.equal(sellerMatches("Amazon.nl", "Amazon"), true);
  assert.equal(sellerMatches(null, "bol"), true);
});

test("datums in Nederlandse tijd", () => {
  assert.equal(dutchDate(Date.parse("2026-11-26T23:30:00Z")), "2026-11-27");
  assert.equal(dutchDate(Date.parse("2026-07-01T21:59:00Z")), "2026-07-01");
  assert.equal(daysBetween("2026-10-20", "2026-11-03"), 14);
  assert.equal(daysBetween("2026-12-07", "2026-12-06"), -1);
});

class MemoryStore implements Store {
  watches: Watch[];
  offers: Array<{ url: string; price: number }> = [];
  failures: string[] = [];
  alerts: NewAlert[] = [];

  constructor(watches: Watch[]) {
    this.watches = watches;
  }
  async activeWatches(today: string): Promise<Watch[]> {
    return this.watches.filter((watch) => watch.returnLastDay >= today).map((watch) => ({ ...watch }));
  }
  async recordOffer(row: { url: string; offer: Offer }): Promise<void> {
    this.offers.push({ url: row.url, price: row.offer.price });
  }
  async recordFailure(row: { reason: string }): Promise<void> {
    this.failures.push(row.reason);
  }
  async savePurchaseState(purchaseId: string, state: PurchaseState): Promise<void> {
    const watch = this.watches.find((candidate) => candidate.purchaseId === purchaseId)!;
    watch.pending = state.pending;
    watch.confirmedCents = state.confirmedCents;
  }
  async createAlert(alert: NewAlert): Promise<boolean> {
    if (this.alerts.some((known) => known.purchaseId === alert.purchaseId && known.newCents === alert.newCents)) return false;
    this.alerts.push(alert);
    return true;
  }
  async deviceTokens(installId: string): Promise<string[]> {
    return [`token-${installId}`];
  }
}

const watch = (extra: Partial<Watch> = {}): Watch => ({
  purchaseId: "p1", installId: "i1", title: "Koptelefoon", url: "https://winkel.example/p/1", ean: null,
  shopName: "Winkel", paidCents: 29900, thresholdCents: 1000, returnLastDay: "2026-12-03", pending: null,
  confirmedCents: null, ...extra,
});

function setup(watches: Watch[], prices: Record<string, number | "kapot">) {
  const store = new MemoryStore(watches);
  const pushes: Array<PushMessage & { token: string }> = [];
  let fetches = 0;
  const run = (now: number, recheckOnly = false) =>
    runDaily({
      store,
      now: () => now,
      recheckOnly,
      adapters: [jsonLdAdapter({ id: "winkel", name: "Winkel", domains: ["winkel.example"] })],
      fetcher: {
        getHtml: async (url) => {
          fetches += 1;
          const price = prices[url];
          if (price === undefined || price === "kapot") return "<html>geen gegevens</html>";
          return `<script type="application/ld+json">{"@type":"Product","offers":{"price":"${(price / 100).toFixed(2)}","priceCurrency":"EUR"}}</script>`;
        },
      },
      push: { send: async (token, message) => void pushes.push({ token, ...message }) },
    });
  return { store, pushes, run, fetchCount: () => fetches };
}

test("dagelijkse taak: lagere prijs geeft precies één melding, na de tweede controle", async () => {
  const prices: Record<string, number> = { "https://winkel.example/p/1": 26100 };
  const { store, pushes, run } = setup([watch()], prices);

  assert.deepEqual(await run(T0), { checked: 1, failed: 0, alerts: 0 });
  assert.equal(pushes.length, 0, "na één controle nog geen melding");

  assert.deepEqual(await run(T0 + 2 * HOUR, true), { checked: 1, failed: 0, alerts: 1 });
  assert.equal(pushes.length, 1);
  assert.equal(pushes[0]?.title, "Koptelefoon is €38 goedkoper");
  assert.equal(pushes[0]?.body, "Je kunt nog 6 dagen retourneren. Bekijk de snelste route.");
  assert.equal(pushes[0]?.token, "token-i1");
  assert.equal(store.watches[0]?.confirmedCents, 26100);

  // De dagen erna dezelfde prijs: geen tweede melding.
  await run(T0 + 26 * HOUR);
  await run(T0 + 50 * HOUR);
  assert.equal(pushes.length, 1);
  assert.equal(store.alerts.length, 1);
});

test("dagelijkse taak: prijs terug omhoog voor de tweede controle geeft geen melding", async () => {
  const prices: Record<string, number> = { "https://winkel.example/p/1": 26100 };
  const { store, pushes, run } = setup([watch()], prices);
  await run(T0);
  prices["https://winkel.example/p/1"] = 29900;
  await run(T0 + 2 * HOUR);
  assert.equal(pushes.length, 0);
  assert.equal(store.watches[0]?.pending, null);
});

test("dagelijkse taak: fouten stoppen de rest niet, elke link één keer, drempel per gebruiker", async () => {
  const shared = "https://winkel.example/p/2";
  const { store, pushes, run, fetchCount } = setup(
    [
      watch({ purchaseId: "kapot", url: "https://winkel.example/p/kapot" }),
      watch({ purchaseId: "elders", url: "https://andere-winkel.example/p/1" }),
      watch({ purchaseId: "a", installId: "ia", url: shared, paidCents: 10000 }),
      watch({ purchaseId: "b", installId: "ib", url: shared, paidCents: 10000, thresholdCents: 5000 }),
      watch({ purchaseId: "verlopen", url: "https://winkel.example/p/3", returnLastDay: "2026-11-01" }),
    ],
    { "https://winkel.example/p/kapot": "kapot", [shared]: 8000, "https://winkel.example/p/3": 100 },
  );
  assert.deepEqual(await run(T0), { checked: 1, failed: 2, alerts: 0 });
  assert.deepEqual(store.failures.sort(), ["geen-adapter", "geen-gestructureerde-gegevens"]);
  assert.equal(fetchCount(), 2, "de gedeelde link is één keer opgehaald, de verlopen aankoop niet");

  await run(T0 + 2 * HOUR);
  assert.deepEqual(pushes.map((push) => push.token), ["token-ia"], "€20 daling haalt de drempel van €50 niet");
});

test("APNs: geldig ondertekend token en payload met de aankoop", () => {
  const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const token = apnsToken({ keyId: "KEY123", teamId: "TEAM123" }, privateKey, 1_800_000_000);
  const [header, claims, signature] = token.split(".") as [string, string, string];
  assert.deepEqual(JSON.parse(Buffer.from(header, "base64url").toString()), { alg: "ES256", kid: "KEY123" });
  assert.deepEqual(JSON.parse(Buffer.from(claims, "base64url").toString()), { iss: "TEAM123", iat: 1_800_000_000 });
  assert.ok(verify("sha256", Buffer.from(`${header}.${claims}`), { key: publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(signature, "base64url")));
  assert.deepEqual(JSON.parse(apnsPayload({ title: "T", body: "B", purchaseId: "p1" })), {
    aps: { alert: { title: "T", body: "B" }, sound: "default" }, purchaseID: "p1",
  });
});

test("sync: aanvraag wordt gecontroleerd en opgeschoond", () => {
  const install = "6F9619FF-8B86-D011-B42D-00C04FC964FF";
  const purchase = {
    id: "11111111-2222-3333-4444-555555555555", title: "Koptelefoon", url: "https://winkel.example/p/1",
    ean: "8712345678906", shopId: "winkel", shopName: "Winkel", paidCents: 29900,
    purchaseDate: "2026-11-20", returnLastDay: "2026-12-06", archived: false,
  };
  const parsed = parseSyncRequest({ installId: install, thresholdCents: 1500, apnsToken: "ab".repeat(32), purchases: [purchase] });
  assert.ok(typeof parsed !== "string");
  assert.equal(parsed.installId, install.toLowerCase());
  assert.equal(parsed.thresholdCents, 1500);
  assert.equal(parsed.purchases[0]?.url, purchase.url);

  const cleaned = parseSyncRequest({ installId: install, purchases: [{ ...purchase, url: "javascript:alert(1)", ean: "abc" }] });
  assert.ok(typeof cleaned !== "string");
  assert.deepEqual([cleaned.purchases[0]?.url, cleaned.purchases[0]?.ean, cleaned.thresholdCents, cleaned.apnsToken], [null, null, 1000, null]);

  assert.equal(parseSyncRequest({ installId: "geen-uuid" }), "installId ontbreekt");
  assert.equal(parseSyncRequest({ installId: install, purchases: [{ ...purchase, paidCents: 299.5 }] }), "ongeldige aankoop");
  assert.equal(parseSyncRequest({ installId: install, purchases: [{ ...purchase, returnLastDay: "6 december" }] }), "ongeldige aankoop");
  assert.equal(parseSyncRequest({ installId: install, outcomes: [{ id: purchase.id, shopId: "w", route: "hack", succeeded: true, amountCents: 1, decidedAt: "2026-12-01T10:00:00Z" }] }), "ongeldige uitkomst");
  assert.equal(parseSyncRequest(null), "ongeldige aanvraag");
});
