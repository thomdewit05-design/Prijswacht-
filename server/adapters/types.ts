/** Eén prijsmeting. Bedragen zijn altijd gehele centen. */
export interface Offer {
  ean: string | null;
  title: string | null;
  imageUrl: string | null;
  /** Prijs in centen. */
  price: number;
  currency: string;
  inStock: boolean;
  isNew: boolean;
  seller: string | null;
}

export type FailureReason =
  | "geen-adapter"
  | "robots-verbiedt"
  | "netwerk"
  | "http-status"
  | "geen-gestructureerde-gegevens"
  | "geen-product"
  | "geen-aanbieding"
  | "prijs-niet-eenduidig"
  | "adapter-fout";

export class AdapterError extends Error {
  reason: FailureReason;
  constructor(reason: FailureReason, detail?: string) {
    super(detail ? `${reason}: ${detail}` : reason);
    this.name = "AdapterError";
    this.reason = reason;
  }
}

/** Haalt pagina's op; zie http.ts voor de nette variant. */
export interface PageFetcher {
  getHtml(url: string): Promise<string>;
}

/** Elke winkel heeft een eigen adapter met dezelfde interface. */
export interface Adapter {
  id: string;
  name: string;
  /** Hostnamen zonder "www.". */
  domains: string[];
  fetchOffer(url: string, fetcher: PageFetcher): Promise<Offer>;
}
