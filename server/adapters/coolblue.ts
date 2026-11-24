import { jsonLdAdapter } from "./shared.ts";

/**
 * Coolblue. Gebruikt de gedeelde JSON-LD-adapter; nog niet gecontroleerd tegen
 * echte productpagina's. Sla voorbeeldpagina's op met study/save-fixture.ts
 * en zet winkelspecifieke uitzonderingen in dit bestand.
 */
export const adapter = jsonLdAdapter({ id: "coolblue", name: "Coolblue", domains: ["coolblue.nl", "coolblue.be"] });
