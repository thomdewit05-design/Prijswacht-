/** Leest products.csv: kolommen shop, url, ean, categorie. */
export interface ProductRow {
  shop: string;
  url: string;
  ean: string | null;
  category: string;
}

export function parseCsvLine(line: string): string[] {
  const fields: string[] = [];
  let current = "";
  let quoted = false;
  for (let index = 0; index < line.length; index++) {
    const char = line[index];
    if (quoted) {
      if (char === '"' && line[index + 1] === '"') {
        current += '"';
        index++;
      } else if (char === '"') {
        quoted = false;
      } else {
        current += char;
      }
    } else if (char === '"') {
      quoted = true;
    } else if (char === "," || char === ";") {
      fields.push(current.trim());
      current = "";
    } else {
      current += char;
    }
  }
  fields.push(current.trim());
  return fields;
}

export function parseProducts(text: string): { rows: ProductRow[]; problems: string[] } {
  const lines = text.replace(/^﻿/, "").split(/\r?\n/).filter((line) => line.trim() !== "");
  const header = parseCsvLine(lines[0] ?? "").map((name) => name.toLowerCase());
  const column = (name: string): number => header.indexOf(name);
  const problems: string[] = [];
  if (column("shop") < 0 || column("url") < 0) {
    return { rows: [], problems: ["De eerste regel moet de kolommen shop,url,ean,categorie bevatten."] };
  }

  const rows: ProductRow[] = [];
  const seen = new Set<string>();
  lines.slice(1).forEach((line, index) => {
    const fields = parseCsvLine(line);
    const url = fields[column("url")] ?? "";
    const shop = (fields[column("shop")] ?? "").toLowerCase();
    const ean = (fields[column("ean")] ?? "").replace(/\D/g, "");
    if (!/^https:\/\//.test(url) || shop === "") {
      problems.push(`Regel ${index + 2}: shop of url ontbreekt of is ongeldig.`);
      return;
    }
    if (seen.has(url)) {
      problems.push(`Regel ${index + 2}: dubbele url, overgeslagen.`);
      return;
    }
    seen.add(url);
    rows.push({ shop, url, ean: ean.length >= 8 ? ean : null, category: fields[column("categorie")] ?? "" });
  });
  return { rows, problems };
}
