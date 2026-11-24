// Edge Function "sync": de app stuurt zijn aankopen en krijgt per aankoop de
// laatste prijs en een eventuele bevestigde daling terug.
import { SupabaseStore } from "../../../jobs/supabase-store.ts";
import { parseSyncRequest } from "../../../jobs/sync-request.ts";

const json = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "alleen POST" }, 405);

  let parsed: ReturnType<typeof parseSyncRequest>;
  try {
    parsed = parseSyncRequest(await request.json());
  } catch {
    return json({ error: "ongeldige aanvraag" }, 400);
  }
  if (typeof parsed === "string") return json({ error: parsed }, 400);

  const store = new SupabaseStore(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
  const upsert = "resolution=merge-duplicates,return=minimal";

  await store.request("POST", "installs?on_conflict=id", {
    id: parsed.installId,
    threshold_cents: parsed.thresholdCents,
    ...(parsed.apnsToken ? { apns_token: parsed.apnsToken } : {}),
    seen_at: new Date().toISOString(),
  }, upsert);

  if (parsed.purchases.length > 0) {
    // Een aankoop van een andere installatie mag niet overschreven worden.
    const ids = parsed.purchases.map((purchase) => purchase.id).join(",");
    const foreign = (await (
      await store.request("GET", `purchases?select=id&id=in.(${ids})&install_id=neq.${parsed.installId}`)
    ).json()) as Array<{ id: string }>;
    const blocked = new Set(foreign.map((row) => row.id));
    const rows = parsed.purchases
      .filter((purchase) => !blocked.has(purchase.id))
      .map((purchase) => ({
        id: purchase.id,
        install_id: parsed.installId,
        title: purchase.title,
        url: purchase.url,
        ean: purchase.ean,
        shop_id: purchase.shopId,
        shop_name: purchase.shopName,
        paid_cents: purchase.paidCents,
        purchase_date: purchase.purchaseDate,
        return_last_day: purchase.returnLastDay,
        archived: purchase.archived,
      }));
    if (rows.length > 0) await store.request("POST", "purchases?on_conflict=id", rows, upsert);
  }

  if (parsed.outcomes.length > 0) {
    await store.request("POST", "outcomes?on_conflict=id", parsed.outcomes.map((outcome) => ({
      id: outcome.id,
      install_id: parsed.installId,
      purchase_id: outcome.purchaseId,
      shop_id: outcome.shopId,
      route: outcome.route,
      succeeded: outcome.succeeded,
      amount_cents: outcome.amountCents,
      decided_at: outcome.decidedAt,
    })), "resolution=ignore-duplicates,return=minimal");
  }

  const states = (await (
    await store.request(
      "GET",
      `purchases?select=id,current_cents,checked_at,confirmed_cents&install_id=eq.${parsed.installId}&archived=is.false`,
    )
  ).json()) as Array<{ id: string; current_cents: number | null; checked_at: string | null; confirmed_cents: number | null }>;

  return json({
    purchases: states.map((row) => ({
      id: row.id,
      currentCents: row.current_cents,
      checkedAt: row.checked_at,
      confirmedCents: row.confirmed_cents,
    })),
  });
});
