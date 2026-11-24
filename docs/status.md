# Status

Laatst bijgewerkt: 24 november 2026.

## Waar we staan

De iOS-app-kern (fase 2) en het routescherm (fase 3) staan in code. Fase 0
(prijsstudie) en fase 1 (prijsmotor op de server) zijn nog niet gebouwd; de
app is dus vóór de eerste poort uit het plan gebouwd.

## Wat er is

- `ios/PrijswachtCore`: bedragen in centen, winkelprofielen, retourtermijn,
  routeadvies met netto besparing, meldingsregels (tweede controle na een
  uur), JSON-LD-lezer, berichten voor de winkel, grenzen van de gratis versie.
  41 tests, allemaal groen (`swift test`, Swift 6.0.3 op Linux).
- `ios/Prijswacht`: tabbladen Bewaakt, Teruggekregen en Instellingen,
  aankoop toevoegen (link plakken of zelf invullen), routescherm met Gelukt en
  Geweigerd, deelkaart, onboarding, betaalmuur (StoreKit 2), lokale meldingen
  (prijsdaling, retourtermijn drie dagen voor het einde).
- `ios/PrijswachtShare`: delen-extensie met bevestigingsscherm.
- `ios/project.yml`: projectbestand voor XcodeGen.

## Niet gecontroleerd

- De SwiftUI-code is nog nooit gebouwd. Ze is geschreven zonder Mac en alleen
  op syntax gecontroleerd. Reken bij de eerste build in Xcode op fouten.
- De JSON-LD-lezer is getest met zelfgemaakte voorbeelden, niet met pagina's
  van echte winkels.
- `ios/Shared/shops.json`: alle winkels staan op de wettelijke 14 dagen, met
  onbekende retourkosten en zonder contactgegevens (`verified: false`).

## Tijdelijke keuzes

- De app haalt de prijs zelf op van de productpagina, bij toevoegen en bij
  omlaag trekken in Bewaakt. Er is nog geen dagelijkse controle; die komt met
  de server. Een daling wordt daardoor pas gemeld als de gebruiker twee keer
  ververst met minstens een uur ertussen.
- Meldingen zijn lokaal. Pushmeldingen (APNs) vragen de server en een
  ontwikkelaarsaccount.
- Abonnementen lopen via StoreKit 2 direct; RevenueCat hoort bij fase 4.
- `SWIFT_VERSION` staat op 5 met strikte concurrency-waarschuwingen aan.

## Eerst doen op een Mac

1. `brew install xcodegen`, dan `cd ios && xcodegen generate` en het project
   openen.
2. Team kiezen, App Group `group.nl.prijswacht.app` aanmaken, bouwfouten
   oplossen.
3. Instellingen > Ontwikkeling > "Laad voorbeeldaankopen" om de schermen te
   doorlopen.

## Open punten

- Fase 0 bouwen (prijsstudie); het meetvenster rond Black Friday begint op
  27 november.
- Winkelprofielen invullen uit de voorwaarden.
- Engelse vertaling afmaken: de String Catalog bevat nu alleen de
  belangrijkste teksten.
- Voorwaarden- en privacypagina's: `AppLinks` wijst naar een tijdelijk adres.
- Abonnementen aanmaken in App Store Connect
  (`nl.prijswacht.plus.jaar`, `nl.prijswacht.plus.maand`).
- Onboarding gebruikt een rekenvoorbeeld; vervangen door echte cijfers uit de
  studie.
- Bon fotograferen (Vision), widget, appicoon.
