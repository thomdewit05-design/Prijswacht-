import { parseJsonLdOffer } from "./jsonld.ts";
import type { Adapter, Offer, PageFetcher } from "./types.ts";

export interface ShopInfo {
  id: string;
  name: string;
  domains: string[];
}

/**
 * Gedeelde standaardadapter: leest de prijs uit JSON-LD. Elke winkel krijgt
 * een eigen bestand dat hierop bouwt, zodat een afwijking bij één winkel
 * daar gerepareerd kan worden zonder de andere te raken.
 */
export function jsonLdAdapter(shop: ShopInfo, adjust?: (offer: Offer, html: string) => Offer): Adapter {
  return {
    ...shop,
    async fetchOffer(url: string, fetcher: PageFetcher): Promise<Offer> {
      const html = await fetcher.getHtml(url);
      const offer = parseJsonLdOffer(html);
      return adjust ? adjust(offer, html) : offer;
    },
  };
}
