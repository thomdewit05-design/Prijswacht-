// Edge Function "lookup": de app stuurt een gedeelde productlink en krijgt
// product en prijs terug. Aanroep: POST { "url": "https://..." }.
import { PoliteFetcher } from "../../../adapters/http.ts";
import { fetchOfferSafely } from "../../../adapters/index.ts";

const json = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "alleen POST" }, 405);

  let url: unknown;
  try {
    url = ((await request.json()) as { url?: unknown }).url;
  } catch {
    return json({ error: "ongeldige aanvraag" }, 400);
  }
  if (typeof url !== "string" || !/^https:\/\//.test(url) || url.length > 2000) {
    return json({ error: "ongeldige link" }, 400);
  }

  const contact = Deno.env.get("PRIJSWACHT_CONTACT");
  if (!contact) return json({ error: "PRIJSWACHT_CONTACT ontbreekt" }, 500);
  const fetcher = new PoliteFetcher({ userAgent: `Prijswacht/0.1 (+${contact})`, timeoutMs: 10_000 });

  const result = await fetchOfferSafely(url, fetcher);
  if (!result.ok) return json({ ok: false, shopId: result.shopId, reason: result.reason });
  return json({ ok: true, shopId: result.shopId, offer: result.offer });
});
