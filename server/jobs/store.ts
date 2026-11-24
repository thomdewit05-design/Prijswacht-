import type { FailureReason, Offer } from "../adapters/types.ts";
import type { PendingDrop } from "./detect.ts";

/** Een aankoop die bewaakt wordt, zoals de dagelijkse taak hem ziet. */
export interface Watch {
  purchaseId: string;
  installId: string;
  title: string;
  url: string;
  ean: string | null;
  shopName: string;
  paidCents: number;
  thresholdCents: number;
  /** Laatste retourdag, JJJJ-MM-DD. */
  returnLastDay: string;
  pending: PendingDrop | null;
  confirmedCents: number | null;
}

export interface PurchaseState {
  currentCents: number;
  checkedAt: number;
  pending: PendingDrop | null;
  confirmedCents: number | null;
}

export interface OfferRow {
  url: string;
  shopId: string;
  offer: Offer;
  observedAt: number;
}

export interface NewAlert {
  purchaseId: string;
  newCents: number;
  dropCents: number;
  route: "askDifference";
}

/** Opslag achter de dagelijkse taak; Supabase in het echt, geheugen in tests. */
export interface Store {
  /** Aankopen met een link, niet gearchiveerd, retourtermijn nog niet voorbij. */
  activeWatches(today: string): Promise<Watch[]>;
  recordOffer(row: OfferRow): Promise<void>;
  recordFailure(row: { url: string; shopId: string | null; reason: FailureReason; detail: string; observedAt: number }): Promise<void>;
  savePurchaseState(purchaseId: string, state: PurchaseState): Promise<void>;
  /** Geeft false als deze melding voor deze aankoop en prijs al bestond. */
  createAlert(alert: NewAlert): Promise<boolean>;
  deviceTokens(installId: string): Promise<string[]>;
}

export interface PushMessage {
  title: string;
  body: string;
  purchaseId: string;
}

export interface PushSender {
  send(deviceToken: string, message: PushMessage): Promise<void>;
}
