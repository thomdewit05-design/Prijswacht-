/** Controle van wat de app naar de sync-functie stuurt. */
export interface SyncPurchase {
  id: string;
  title: string;
  url: string | null;
  ean: string | null;
  shopId: string;
  shopName: string;
  paidCents: number;
  purchaseDate: string;
  returnLastDay: string;
  archived: boolean;
}

export interface SyncOutcome {
  id: string;
  purchaseId: string | null;
  shopId: string;
  route: "askDifference" | "returnAndReorder" | "priceGuarantee";
  succeeded: boolean;
  amountCents: number;
  decidedAt: string;
}

export interface SyncRequest {
  installId: string;
  apnsToken: string | null;
  thresholdCents: number;
  purchases: SyncPurchase[];
  outcomes: SyncOutcome[];
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const ROUTES = ["askDifference", "returnAndReorder", "priceGuarantee"];

const isUuid = (value: unknown): value is string => typeof value === "string" && UUID.test(value);
const isText = (value: unknown, max: number): value is string =>
  typeof value === "string" && value.length > 0 && value.length <= max;
const isCents = (value: unknown): value is number =>
  typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 1_000_000_000;
const optionalText = (value: unknown, max: number): string | null => (isText(value, max) ? value : null);

/** Geeft de gecontroleerde aanvraag terug, of een foutmelding als tekst. */
export function parseSyncRequest(body: unknown): SyncRequest | string {
  if (typeof body !== "object" || body === null) return "ongeldige aanvraag";
  const input = body as Record<string, unknown>;
  if (!isUuid(input.installId)) return "installId ontbreekt";

  const rawPurchases = Array.isArray(input.purchases) ? input.purchases : [];
  const rawOutcomes = Array.isArray(input.outcomes) ? input.outcomes : [];
  if (rawPurchases.length > 500 || rawOutcomes.length > 500) return "te veel regels";

  const purchases: SyncPurchase[] = [];
  for (const raw of rawPurchases as Array<Record<string, unknown>>) {
    if (
      typeof raw !== "object" || raw === null || !isUuid(raw.id) || !isText(raw.title, 300) ||
      !isText(raw.shopId, 100) || !isText(raw.shopName, 100) || !isCents(raw.paidCents) || raw.paidCents === 0 ||
      typeof raw.purchaseDate !== "string" || !DATE.test(raw.purchaseDate) ||
      typeof raw.returnLastDay !== "string" || !DATE.test(raw.returnLastDay)
    ) {
      return "ongeldige aankoop";
    }
    const url = optionalText(raw.url, 2000);
    purchases.push({
      id: raw.id.toLowerCase(),
      title: raw.title,
      url: url !== null && /^https:\/\//.test(url) ? url : null,
      ean: typeof raw.ean === "string" && /^\d{8,14}$/.test(raw.ean) ? raw.ean : null,
      shopId: raw.shopId,
      shopName: raw.shopName,
      paidCents: raw.paidCents,
      purchaseDate: raw.purchaseDate,
      returnLastDay: raw.returnLastDay,
      archived: raw.archived === true,
    });
  }

  const outcomes: SyncOutcome[] = [];
  for (const raw of rawOutcomes as Array<Record<string, unknown>>) {
    if (
      typeof raw !== "object" || raw === null || !isUuid(raw.id) || !isText(raw.shopId, 100) ||
      typeof raw.route !== "string" || !ROUTES.includes(raw.route) || typeof raw.succeeded !== "boolean" ||
      !isCents(raw.amountCents) || typeof raw.decidedAt !== "string" || Number.isNaN(Date.parse(raw.decidedAt))
    ) {
      return "ongeldige uitkomst";
    }
    outcomes.push({
      id: raw.id.toLowerCase(),
      purchaseId: isUuid(raw.purchaseId) ? raw.purchaseId.toLowerCase() : null,
      shopId: raw.shopId,
      route: raw.route as SyncOutcome["route"],
      succeeded: raw.succeeded,
      amountCents: raw.amountCents,
      decidedAt: new Date(raw.decidedAt).toISOString(),
    });
  }

  const threshold = isCents(input.thresholdCents) && input.thresholdCents > 0 ? input.thresholdCents : 1000;
  const token = typeof input.apnsToken === "string" && /^[0-9a-f]{32,200}$/i.test(input.apnsToken) ? input.apnsToken : null;
  return { installId: input.installId.toLowerCase(), apnsToken: token, thresholdCents: threshold, purchases, outcomes };
}
