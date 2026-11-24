/**
 * Leest een bedrag naar gehele centen: "1.299,00", "1299.00", 899, "€ 38,5".
 * Geeft null bij onzin. Rekent nooit met kommagetallen.
 */
export function parseCents(value: unknown): number | null {
  let text: string;
  if (typeof value === "number") {
    if (!Number.isFinite(value) || value < 0) return null;
    text = String(value);
  } else if (typeof value === "string") {
    text = value;
  } else {
    return null;
  }

  const cleaned = text.replace(/[^0-9.,]/g, "");
  if (!/[0-9]/.test(cleaned)) return null;

  // Het laatste scheidingsteken is het decimaalteken als er 1 of 2 cijfers
  // achter staan; anders is het een duizendtalscheiding.
  let whole = cleaned;
  let fraction = "";
  const last = Math.max(cleaned.lastIndexOf("."), cleaned.lastIndexOf(","));
  if (last >= 0) {
    const tail = cleaned.slice(last + 1);
    if (tail.length === 1 || tail.length === 2) {
      whole = cleaned.slice(0, last);
      fraction = tail;
    }
  }
  whole = whole.replace(/[.,]/g, "");
  if (fraction.length === 1) fraction += "0";

  const euros = Number.parseInt(whole === "" ? "0" : whole, 10);
  const rest = Number.parseInt(fraction === "" ? "0" : fraction, 10);
  if (!Number.isSafeInteger(euros) || euros > 10_000_000) return null;
  return euros * 100 + rest;
}

/** "€38", "€38,50", "€1.299". */
export function formatEuro(cents: number): string {
  const sign = cents < 0 ? "-" : "";
  const value = Math.abs(cents);
  const euros = Math.floor(value / 100).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  const rest = value % 100;
  return rest === 0 ? `${sign}€${euros}` : `${sign}€${euros},${rest.toString().padStart(2, "0")}`;
}
