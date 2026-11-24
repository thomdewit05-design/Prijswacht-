# Prijswacht

App die de prijs van gedane aankopen bewaakt en de gebruiker helpt het
verschil terug te krijgen. Zie docs/concept.md. Begin elke sessie met
docs/status.md.

## Stack
iOS: Swift 6, SwiftUI, iOS 17+, SwiftData, Share Extension, StoreKit 2
via RevenueCat. Server: Supabase (Postgres, cron, Edge Functions),
prijsadapters in TypeScript.

## Mappen
- `ios/PrijswachtCore/` Swift-package met alle rekenlogica, zonder UI.
  Testen: `cd ios/PrijswachtCore && swift test` (werkt ook op Linux).
- `ios/Prijswacht/` hoofdapp (SwiftUI): `Features/`, `Core/`.
- `ios/PrijswachtShare/` delen-extensie.
- `ios/Shared/` code en bestanden voor app én extensie (App Group-opslag).
- `ios/PrijswachtWidgets/` widget met de teller en de eerstvolgende retourtermijn.
- `ios/project.yml` Xcode-project via XcodeGen: `cd ios && xcodegen generate`.
- `server/` prijsmotor in TypeScript zonder bouwstap (Node 22.18+):
  `adapters/`, `jobs/`, `supabase/`, `tests/`. Testen: `cd server && npm test`
  en `npm run typecheck`.
- `study/` prijsstudie (fase 0); gebruikt de adapters uit `server/`.
- De meldingsregels staan twee keer: `ios/PrijswachtCore/.../DropDetector.swift`
  en `server/jobs/detect.ts`. Wijzig ze altijd samen.

## Regels
- Bedragen altijd als gehele centen (Int), nooit als Double.
- Elke winkel heeft een eigen adapter met dezelfde interface:
  fetchOffer(url) -> { ean, price, currency, inStock, seller }.
  Een kapotte adapter mag de andere niet raken.
- Een prijsdaling wordt pas een melding na een tweede controle, minstens
  een uur later, en alleen bij: nieuw, zelfde verkoper, op voorraad.
- Producten koppelen op EAN of exacte variant-url, nooit op titel.
- Sla van bestelmails alleen product, prijs, winkel en datum op.
- Geen tekst in de app die geld terug belooft. Gebruik "kan", niet "krijgt".
- Teksten via String Catalogs, Nederlands en Engels.
- Elke adapter heeft tests met opgeslagen voorbeeldpagina's.
- Winkelregels (retourtermijn, retourkosten, prijsgarantie) worden door een
  mens uit de voorwaarden overgenomen in `ios/Shared/shops.json`, nooit
  geschat. Zet `verified` pas op true na die controle.
- Rekenlogica hoort in PrijswachtCore, met tests; views rekenen niet zelf.

## Werkwijze
- Maak eerst een plan en wacht op akkoord bij nieuwe adapters en bij
  wijzigingen in de meldingslogica.
- Kleine commits. Werk docs/status.md bij aan het eind van elke sessie.
