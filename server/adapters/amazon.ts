import { jsonLdAdapter } from "./shared.ts";

/**
 * Amazon.nl. Gebruikt de gedeelde JSON-LD-adapter; nog niet gecontroleerd tegen
 * echte productpagina's. Sla voorbeeldpagina's op met study/save-fixture.ts
 * en zet winkelspecifieke uitzonderingen in dit bestand.
 */
export const adapter = jsonLdAdapter({ id: "amazon-nl", name: "Amazon.nl", domains: ["amazon.nl"] });
