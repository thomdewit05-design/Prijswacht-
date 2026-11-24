import type { NewAlert, OfferRow, PurchaseState, Store, Watch } from "./store.ts";

/**
 * Opslag in Supabase via de REST-interface (PostgREST), met de
 * service-role-sleutel. Werkt in Node en in Edge Functions.
 */
export class SupabaseStore implements Store {
  private baseUrl: string;
  private key: string;

  constructor(projectUrl: string, serviceRoleKey: string) {
    this.baseUrl = `${projectUrl.replace(/\/$/, "")}/rest/v1`;
    this.key = serviceRoleKey;
  }

  async request(method: string, path: string, body?: unknown, prefer?: string): Promise<Response> {
    const response = await fetch(`${this.baseUrl}/${path}`, {
      method,
      headers: {
        apikey: this.key,
        Authorization: `Bearer ${this.key}`,
        "Content-Type": "application/json",
        ...(prefer ? { Prefer: prefer } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!response.ok) {
      throw new Error(`Supabase ${method} ${path.split("?")[0]}: ${response.status} ${await response.text()}`);
    }
    return response;
  }

  async activeWatches(today: string): Promise<Watch[]> {
    const query =
      "purchases?select=id,install_id,title,url,ean,shop_name,paid_cents,return_last_day," +
      "pending_cents,pending_seen_at,confirmed_cents,installs(threshold_cents)" +
      `&archived=is.false&url=not.is.null&return_last_day=gte.${today}`;
    const rows = (await (await this.request("GET", query)).json()) as Array<Record<string, any>>;
    return rows.map((row) => ({
      purchaseId: row.id,
      installId: row.install_id,
      title: row.title,
      url: row.url,
      ean: row.ean,
      shopName: row.shop_name,
      paidCents: row.paid_cents,
      thresholdCents: row.installs?.threshold_cents ?? 1000,
      returnLastDay: row.return_last_day,
      pending:
        row.pending_cents !== null && row.pending_seen_at !== null
          ? { priceCents: row.pending_cents, firstSeenAt: Date.parse(row.pending_seen_at) }
          : null,
      confirmedCents: row.confirmed_cents,
    }));
  }

  async recordOffer(row: OfferRow): Promise<void> {
    await this.request("POST", "offers", {
      url: row.url,
      shop_id: row.shopId,
      ean: row.offer.ean,
      price_cents: row.offer.price,
      currency: row.offer.currency,
      in_stock: row.offer.inStock,
      is_new: row.offer.isNew,
      seller: row.offer.seller,
      observed_at: new Date(row.observedAt).toISOString(),
    });
  }

  async recordFailure(row: Parameters<Store["recordFailure"]>[0]): Promise<void> {
    await this.request("POST", "price_failures", {
      url: row.url,
      shop_id: row.shopId,
      reason: row.reason,
      detail: row.detail.slice(0, 500),
      observed_at: new Date(row.observedAt).toISOString(),
    });
  }

  async savePurchaseState(purchaseId: string, state: PurchaseState): Promise<void> {
    await this.request("PATCH", `purchases?id=eq.${purchaseId}`, {
      current_cents: state.currentCents,
      checked_at: new Date(state.checkedAt).toISOString(),
      pending_cents: state.pending?.priceCents ?? null,
      pending_seen_at: state.pending ? new Date(state.pending.firstSeenAt).toISOString() : null,
      confirmed_cents: state.confirmedCents,
    });
  }

  async createAlert(alert: NewAlert): Promise<boolean> {
    const response = await this.request(
      "POST",
      "alerts?on_conflict=purchase_id,new_cents",
      { purchase_id: alert.purchaseId, new_cents: alert.newCents, drop_cents: alert.dropCents, route: alert.route },
      "resolution=ignore-duplicates,return=representation",
    );
    return ((await response.json()) as unknown[]).length > 0;
  }

  async deviceTokens(installId: string): Promise<string[]> {
    const rows = (await (
      await this.request("GET", `installs?select=apns_token&id=eq.${installId}&apns_token=not.is.null`)
    ).json()) as Array<{ apns_token: string }>;
    return rows.map((row) => row.apns_token);
  }
}
