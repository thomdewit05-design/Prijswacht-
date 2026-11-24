// Slaat een echte productpagina op als voorbeeld voor de adaptertests.
//   PRIJSWACHT_CONTACT=mailto:jij@voorbeeld.nl node study/save-fixture.ts <url> [naam]
// Controleer daarna het .expected.json-bestand met de hand tegen de pagina.
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { PoliteFetcher } from "../server/adapters/http.ts";
import { adapterFor } from "../server/adapters/index.ts";
import { contactOrExit, studyDir } from "./run.ts";

const contact = contactOrExit();
const url = process.argv[2];
const adapter = url ? adapterFor(url) : null;
if (!url || adapter === null) {
  console.error("Geef de link van een productpagina van een winkel met een adapter.");
  process.exit(2);
}

const html = await new PoliteFetcher({ userAgent: `PrijswachtStudie/0.1 (+${contact})` }).getHtml(url);
const name = (process.argv[3] ?? new URL(url).pathname.replace(/[^a-z0-9]+/gi, "-").replace(/^-|-$/g, "")).slice(0, 60);
const folder = join(studyDir, "..", "server", "tests", "fixtures", adapter.id);
mkdirSync(folder, { recursive: true });
writeFileSync(join(folder, `${name}.html`), html);

let expected: unknown;
try {
  expected = await adapter.fetchOffer(url, { getHtml: async () => html });
} catch (error) {
  expected = { fout: error instanceof Error ? error.message : String(error) };
}
writeFileSync(join(folder, `${name}.expected.json`), `${JSON.stringify(expected, null, 2)}\n`);
console.log(`Opgeslagen in ${folder}. Controleer ${name}.expected.json met de hand.`);
