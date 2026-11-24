import type { Offer } from "../adapters/types.ts";

/** Een daling die één keer gezien is en op de tweede controle wacht. */
export interface PendingDrop {
  priceCents: number;
  /** Tijdstip in milliseconden sinds 1970. */
  firstSeenAt: number;
}

export type DropDecision =
  | { kind: "none" }
  | { kind: "pending"; pending: PendingDrop }
  | { kind: "confirmed"; priceCents: number; dropCents: number };

export const MIN_CONFIRMATION_MS = 60 * 60 * 1000;

const normalizeSeller = (name: string): string =>
  name.toLowerCase().replace(".com", "").replace(".nl", "").replace(/[^\p{L}\p{N}]/gu, "");

/** Een onbekende verkoper keuren we goed; een andere dan de winkel zelf niet. */
export function sellerMatches(seller: string | null, expected: string | null): boolean {
  const a = seller ? normalizeSeller(seller) : "";
  const b = expected ? normalizeSeller(expected) : "";
  if (a === "" || b === "") return true;
  return a.includes(b) || b.includes(a);
}

/**
 * Valse meldingen zijn dodelijk. Een prijsdaling wordt pas een melding na
 * een tweede controle, minstens een uur later, en alleen bij: nieuw, zelfde
 * verkoper, op voorraad, in euro's en boven de drempel.
 *
 * Dezelfde regels staan in ios/PrijswachtCore (DropDetector.swift); houd ze
 * gelijk.
 */
export function evaluateDrop(input: {
  offer: Offer;
  paidCents: number;
  thresholdCents: number;
  expectedSeller: string | null;
  pending: PendingDrop | null;
  now: number;
}): DropDecision {
  const { offer, paidCents, thresholdCents, pending, now } = input;
  if (
    offer.currency.toUpperCase() !== "EUR" ||
    !offer.isNew ||
    !offer.inStock ||
    offer.price <= 0 ||
    !sellerMatches(offer.seller, input.expectedSeller)
  ) {
    return { kind: "none" };
  }

  const drop = paidCents - offer.price;
  if (drop <= 0 || drop < thresholdCents) return { kind: "none" };

  if (pending === null) {
    return { kind: "pending", pending: { priceCents: offer.price, firstSeenAt: now } };
  }
  if (now - pending.firstSeenAt < MIN_CONFIRMATION_MS) {
    return {
      kind: "pending",
      pending: { priceCents: Math.max(pending.priceCents, offer.price), firstSeenAt: pending.firstSeenAt },
    };
  }
  // Meld de voorzichtigste daling: de hoogste prijs van beide metingen.
  const priceCents = Math.max(pending.priceCents, offer.price);
  return { kind: "confirmed", priceCents, dropCents: paidCents - priceCents };
}
