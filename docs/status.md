# Status

Laatst bijgewerkt: 24 november 2026.

## Waar we staan

Alle onderdelen uit het plan staan in code: de prijsstudie (fase 0), de
prijsmotor (fase 1), de app-kern (fase 2), het routescherm (fase 3), de
betaalmuur (fase 4, zonder RevenueCat) en de widget (fase 5). Er is nog niets
uitgerold en nog geen dag gemeten. De app is vóór de eerste poort gebouwd.

## Getest in deze omgeving

- `ios/PrijswachtCore`: 47 tests groen (`swift test`, Swift 6.0.3 op Linux).
- `server` en `study`: 23 tests groen, typecontrole schoon (`npm test`,
  `npm run typecheck`). Daarin: precies één melding na de tweede controle,
  geen melding als de prijs weer stijgt, één verzoek per vijf seconden per
  winkel, robots.txt, de analyse van de studie.

## Niet gecontroleerd

- De SwiftUI-code (app, delen-extensie, widget) is nog nooit gebouwd. Ze is
  geschreven zonder Mac en alleen op syntax gecontroleerd. Reken bij de eerste
  build in Xcode op fouten. Xcode 16 of nieuwer is nodig.
- Geen enkele adapter heeft een echte productpagina gezien: de winkels waren
  vanuit de bouwomgeving niet bereikbaar. Vijf adaptertests staan daarom op
  "todo". `study/check.ts` laat per winkel zien of het werkt.
- Supabase (schema, Edge Functions) en APNs zijn niet uitgerold of
  aangeroepen.
- `ios/Shared/shops.json`: alle winkels staan op de wettelijke 14 dagen, met
  onbekende retourkosten en zonder contactgegevens (`verified: false`).
- Het sync-eindpunt vertrouwt op een willekeurig installatie-id als sleutel;
  er zijn geen accounts. Laat dat beoordelen voor de lancering.

## Eerst doen

1. Prijsstudie starten vóór Black Friday (27 november): zie `study/README.md`.
   Productlijst maken, `check.ts` draaien, daarna dagelijks `run.ts`.
2. Per winkel een paar echte pagina's opslaan met `study/save-fixture.ts`.
3. Op een Mac: `brew install xcodegen`, `cd ios && xcodegen generate`, team
   kiezen, App Group `group.nl.prijswacht.app` aanmaken, bouwfouten oplossen.
   Instellingen > Ontwikkeling > "Laad voorbeeldaankopen" toont de schermen.
4. Supabase-project aanmaken (EU), migratie en functies uitrollen, en
   `PRIJSWACHT_SERVER_URL` en `PRIJSWACHT_ANON_KEY` invullen in
   `ios/project.yml`. Zonder die twee werkt de app zelfstandig.

## Tijdelijke keuzes

- Zonder server haalt de app de prijs zelf op, bij toevoegen en bij omlaag
  trekken in Bewaakt, en zijn meldingen lokaal.
- Abonnementen lopen via StoreKit 2 direct; RevenueCat is niet gekoppeld.
- `SWIFT_VERSION` staat op 5 met strikte concurrency-waarschuwingen aan.
- De studie is in TypeScript in plaats van Python, zodat hij de adapters van
  de server gebruikt.

## Open punten

- Winkelprofielen invullen uit de voorwaarden.
- Engelse vertaling afmaken: de String Catalog bevat alleen de belangrijkste
  teksten.
- Voorwaarden- en privacypagina's: `AppLinks` wijst naar een tijdelijk adres.
- Abonnementen aanmaken in App Store Connect
  (`nl.prijswacht.plus.jaar`, `nl.prijswacht.plus.maand`).
- Onboarding gebruikt een rekenvoorbeeld; vervangen door cijfers uit de studie.
- Appicoon, analysegebeurtenissen, account verwijderen (wis-eindpunt op de
  server), TestFlight.
- Versie 1.5: bestelmail doorsturen, andere winkels op EAN, route 3 in de
  dagelijkse taak (de app-logica voor route 3 bestaat al).
