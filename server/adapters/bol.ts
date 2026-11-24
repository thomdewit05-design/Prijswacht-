import { jsonLdAdapter } from "./shared.ts";

/**
 * bol. Gebruikt de gedeelde JSON-LD-adapter; nog niet gecontroleerd tegen
 * echte productpagina's. Sla voorbeeldpagina's op met study/save-fixture.ts
 * en zet winkelspecifieke uitzonderingen in dit bestand.
 */
export const adapter = jsonLdAdapter({ id: "bol", name: "bol", domains: ["bol.com"] });
