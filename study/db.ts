import { DatabaseSync } from "node:sqlite";

export interface PriceRow {
  date: string;
  shop: string;
  url: string;
  ean: string | null;
  category: string;
  /** Prijs in centen. */
  priceCents: number;
  inStock: boolean;
}

export class StudyDb {
  private db: DatabaseSync;

  constructor(path: string) {
    this.db = new DatabaseSync(path);
    this.db.exec(`
      create table if not exists prijzen (
        datum text not null,
        shop text not null,
        url text not null,
        ean text,
        categorie text not null default '',
        prijs integer not null,
        valuta text not null default 'EUR',
        op_voorraad integer not null,
        primary key (datum, url)
      );
      create table if not exists fouten (
        datum text not null,
        shop text not null,
        url text not null,
        reden text not null,
        detail text
      );
    `);
  }

  /** Eén regel per product per dag; een tweede run op dezelfde dag vervangt. */
  savePrice(row: PriceRow, currency = "EUR"): void {
    this.db
      .prepare(
        `insert or replace into prijzen (datum, shop, url, ean, categorie, prijs, valuta, op_voorraad)
         values (?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(row.date, row.shop, row.url, row.ean, row.category, row.priceCents, currency, row.inStock ? 1 : 0);
  }

  saveFailure(row: { date: string; shop: string; url: string; reason: string; detail: string }): void {
    this.db
      .prepare("insert into fouten (datum, shop, url, reden, detail) values (?, ?, ?, ?, ?)")
      .run(row.date, row.shop, row.url, row.reason, row.detail);
  }

  hasPrice(date: string, url: string): boolean {
    return this.db.prepare("select 1 from prijzen where datum = ? and url = ?").get(date, url) !== undefined;
  }

  prices(): PriceRow[] {
    const rows = this.db
      .prepare("select datum, shop, url, ean, categorie, prijs, op_voorraad from prijzen where valuta = 'EUR' order by url, datum")
      .all() as Array<Record<string, string | number | null>>;
    return rows.map((row) => ({
      date: String(row.datum),
      shop: String(row.shop),
      url: String(row.url),
      ean: row.ean === null ? null : String(row.ean),
      category: String(row.categorie),
      priceCents: Number(row.prijs),
      inStock: Number(row.op_voorraad) === 1,
    }));
  }

  close(): void {
    this.db.close();
  }
}
