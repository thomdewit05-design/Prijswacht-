import { parseCents } from "./money.ts";
import { AdapterError, type Offer } from "./types.ts";

type Json = Record<string, unknown>;

const isObject = (value: unknown): value is Json =>
  typeof value === "object" && value !== null && !Array.isArray(value);

/** Alle JSON-LD-blokken uit een pagina, als tekst. */
export function jsonLdBlocks(html: string): string[] {
  const blocks: string[] = [];
  const pattern = /<script\b([^>]*)>([\s\S]*?)<\/script/gi;
  for (const match of html.matchAll(pattern)) {
    if ((match[1] ?? "").toLowerCase().includes("application/ld+json")) {
      blocks.push(match[2] ?? "");
    }
  }
  return blocks;
}

function typesOf(object: Json): string[] {
  const raw = object["@type"];
  const list = typeof raw === "string" ? [raw] : Array.isArray(raw) ? raw : [];
  return list
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.toLowerCase().replace("schema:", ""));
}

function collectProducts(json: unknown, into: Json[]): void {
  if (Array.isArray(json)) {
    for (const item of json) collectProducts(item, into);
  } else if (isObject(json)) {
    if (typesOf(json).includes("product")) into.push(json);
    if (json["@graph"] !== undefined) collectProducts(json["@graph"], into);
    if (json["mainEntity"] !== undefined) collectProducts(json["mainEntity"], into);
  }
}

function eanFrom(object: Json): string | null {
  for (const key of ["gtin13", "gtin", "gtin14", "gtin12", "gtin8"]) {
    const value = object[key];
    if (typeof value !== "string" && typeof value !== "number") continue;
    const digits = String(value).replace(/\D/g, "");
    if (digits.length >= 8 && digits.length <= 14) return digits;
  }
  return null;
}

function imageFrom(value: unknown): string | null {
  if (typeof value === "string") return value;
  if (Array.isArray(value)) return imageFrom(value[0]);
  if (isObject(value)) return imageFrom(value["url"] ?? value["contentUrl"]);
  return null;
}

function nameFrom(value: unknown): string | null {
  if (typeof value === "string") return value;
  if (isObject(value) && typeof value["name"] === "string") return value["name"];
  return null;
}

function offerFromProduct(product: Json): Offer {
  const rawOffers = product["offers"];
  const candidates = (Array.isArray(rawOffers) ? rawOffers : [rawOffers]).filter(isObject);
  if (candidates.length === 0) throw new AdapterError("geen-aanbieding");

  // AggregateOffer: gebruik de losse aanbiedingen als die erbij staan, en
  // anders alleen als laagste en hoogste prijs gelijk zijn. Een "vanaf"-prijs
  // is geen prijs waar we een melding op durven baseren.
  const offers: Json[] = [];
  for (const candidate of candidates) {
    if (!typesOf(candidate).includes("aggregateoffer")) {
      offers.push(candidate);
      continue;
    }
    const nested = candidate["offers"];
    if (Array.isArray(nested) && nested.some(isObject)) {
      offers.push(...nested.filter(isObject));
      continue;
    }
    const low = parseCents(candidate["lowPrice"]);
    const high = parseCents(candidate["highPrice"] ?? candidate["lowPrice"]);
    const count = Number(candidate["offerCount"] ?? 1);
    if (low !== null && low === high && count <= 1) {
      offers.push({ ...candidate, price: candidate["lowPrice"] });
    } else {
      throw new AdapterError("prijs-niet-eenduidig", "alleen een vanaf-prijs");
    }
  }

  const priced: Offer[] = [];
  for (const raw of offers) {
    const specification = isObject(raw["priceSpecification"]) ? raw["priceSpecification"] : {};
    const price = parseCents(raw["price"]) ?? parseCents(specification["price"]);
    if (price === null || price <= 0) continue;
    const currency = raw["priceCurrency"] ?? specification["priceCurrency"];
    const availability = typeof raw["availability"] === "string" ? raw["availability"].toLowerCase() : "";
    const condition = typeof raw["itemCondition"] === "string" ? raw["itemCondition"].toLowerCase() : "";
    const title = typeof product["name"] === "string" ? product["name"].trim() : null;
    priced.push({
      ean: eanFrom(product) ?? eanFrom(raw),
      title,
      imageUrl: imageFrom(product["image"]),
      price,
      currency: typeof currency === "string" ? currency.toUpperCase() : "EUR",
      // Zonder vermelding gaan we uit van op voorraad en nieuw.
      inStock:
        availability === "" ||
        availability.endsWith("instock") ||
        availability.endsWith("limitedavailability") ||
        availability.endsWith("onlineonly"),
      isNew: condition === "" || condition.endsWith("newcondition"),
      seller: nameFrom(raw["seller"]),
    });
  }
  if (priced.length === 0) throw new AdapterError("geen-aanbieding");

  // Meerdere aanbiedingen met verschillende prijzen (marktplaats,
  // tweedekans) zijn niet eenduidig.
  const newInStock = priced.filter((offer) => offer.isNew && offer.inStock);
  const pool = newInStock.length > 0 ? newInStock : priced;
  const first = pool[0];
  if (first === undefined || new Set(pool.map((offer) => offer.price)).size !== 1) {
    throw new AdapterError("prijs-niet-eenduidig", "meerdere prijzen");
  }
  return first;
}

/** Leest product en prijs uit schema.org Product/Offer in JSON-LD. */
export function parseJsonLdOffer(html: string): Offer {
  const blocks = jsonLdBlocks(html);
  if (blocks.length === 0) throw new AdapterError("geen-gestructureerde-gegevens");

  const products: Json[] = [];
  for (const block of blocks) {
    try {
      collectProducts(JSON.parse(block), products);
    } catch {
      // Kapot blok: overslaan, een later blok kan wel goed zijn.
    }
  }
  if (products.length === 0) throw new AdapterError("geen-product");

  let lastError: unknown = new AdapterError("geen-aanbieding");
  for (const product of products) {
    try {
      return offerFromProduct(product);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError;
}
