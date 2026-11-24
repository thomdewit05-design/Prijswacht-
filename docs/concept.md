# Prijswacht: geld terug als de prijs daalt na je aankoop

Samenvatting van het conceptdocument van 23 november 2026. Prijswacht is een
werknaam.

## Het idee

Prijswacht bewaakt de prijs van wat je online koopt. Je deelt een aankoop met
de app. Zolang je retourtermijn loopt, wordt de prijs elke dag gecontroleerd.
Daalt de prijs, dan krijg je een melding met het bedrag en de snelste weg naar
je geld.

Waarom dit in Europa kan werken: bij online aankopen heb je in de EU 14 dagen
bedenktijd. Je mag dus retourneren en opnieuw bestellen tegen de lagere prijs,
en winkels komen je vaak tegemoet om die retour te voorkomen. In de VS bestaat
deze categorie al (Paribus en vergelijkbare apps); in Nederland is er alleen
prijsbewaking vóór aankoop.

De grote onbekende is hoe vaak prijzen binnen 14 tot 30 dagen na aankoop dalen.
Daarom begint het plan met een prijsstudie, vóór de app.

## Hoe het werkt

1. Aankoop toevoegen: productpagina delen vanuit Safari of de winkelapp,
   later ook een bestelbevestiging doorsturen of een bon fotograferen.
2. De app leest product, prijs, winkel en datum uit en zet de retourtermijn
   van die winkel erbij.
3. Dagelijkse controle bij dezelfde winkel, later ook bij andere winkels.
4. Melding bij een daling boven jouw drempel (standaard €10).
5. Eén scherm met de beste route en een kant-en-klaar bericht.
6. De teller loopt op: "Dit jaar teruggekregen".

## De drie routes

| Route | Wanneer | Zekerheid |
| --- | --- | --- |
| 1. Vraag het verschil | Zelfde winkel is goedkoper geworden | Geen recht, wel vaak coulance |
| 2. Retourneer en bestel opnieuw | Bedenktijd loopt nog en route 1 is geweigerd | Wettelijk recht bij online aankopen, met uitzonderingen |
| 3. Claim de laagsteprijsgarantie | Andere winkel is goedkoper en jouw winkel belooft de laagste prijs | Hangt af van de voorwaarden |

Route 1 is altijd de eerste keuze. Commissie mag nooit bepalen welke route de
app aanraadt.

## Wat het bewust niet is

- Geen app die namens jou claimt of in je mailbox meeleest.
- Geen kortingscodes of cashback.
- Geen juridisch advies.

## MVP (versie 1.0)

Delen-knop, handmatig toevoegen en bon fotograferen, winkelprofielen,
dagelijkse prijscontrole, melding bij daling, routescherm, aftelling van de
retourtermijn, besparingsteller met deelkaart, abonnement (gratis tot drie
lopende aankopen). Start met vijf tot acht grote winkels.

Later: bestelmail doorsturen, andere winkels op EAN, route 3, widget (1.5);
prijsalert vóór aankoop, garantiekluis, gedeeld huishouden, Android (2.0).

## Schermen

Drie tabbladen: Bewaakt, Teruggekregen, Instellingen. Het routescherm toont
van boven naar beneden: het bedrag, de resterende tijd, de aanbevolen route
met netto bedrag, de knop Bericht klaarzetten, en Gelukt of Geweigerd. Die
laatste twee vullen de teller en leren de app het slagingspercentage per
winkel.

Ontwerpprincipes: rustig en betrouwbaar, bedragen zijn het ontwerp (groot,
groen, netto), volledig native, eerlijk over onzekerheid ("winkels zijn dit
niet verplicht" staat op het routescherm).

## Techniek

Datamodel: shops, products, offers (prijsgeschiedenis), purchases, alerts.

Prijzen ophalen, in deze volgorde: productfeeds van affiliatenetwerken,
gestructureerde gegevens op de productpagina (JSON-LD), en als laatste middel
de pagina zelf. Lees per winkel de voorwaarden en robots.txt.

Vier valkuilen: het juiste product (koppel op EAN of variant-url),
nepdalingen (alleen nieuw, zelfde verkoper, op voorraad), valse meldingen
(altijd een tweede controle), privacy (bewaar alleen product, prijs, winkel,
datum).

## Verdienmodel

| | Gratis | Plus |
| --- | --- | --- |
| Lopende aankopen | 3 tegelijk | Onbeperkt |
| Prijscontrole | Dagelijks, zelfde winkel | Vaker, ook andere winkels |
| Routescherm en bericht | Bij de eerste treffer | Altijd |
| Mail doorsturen, garantiekluis, widgets | Nee | Ja |

Voorstel om te testen: jaar €19,99, maand €2,99, eenmalig per treffer €2,99.
Tweede stroom: affiliate bij opnieuw bestellen, open benoemd in de app.

Drie getallen bepalen alles: trefkans, slagingskans en verlenging.

## Roadmap en poorten

| Fase | Periode | Poort |
| --- | --- | --- |
| 1. Prijsstudie | nov 2026 tot jan 2027 | 1 op 20 producten daalt minstens €10 |
| 2. MVP bouwen | feb tot mrt 2027 | 1 op 5 testers vindt een besparing |
| 3. Lancering | apr tot jun 2027 | 500 betalende abonnees vóór Black Friday 2027 |
| 4. Opschalen | vanaf jul 2027 | |

Stopcriterium: daalt in de studie minder dan 1 op de 20 producten binnen 30
dagen met minstens €10, dan wordt de app niet gebouwd.

## Bouwfasen

0. Prijsstudie. 1. Prijsmotor. 2. App-kern. 3. Routescherm. 4. Betalen en
meten. 5. Afronden. 6. Versie 1.5.

## Nog te controleren

De rekensommen, drempels en slagingskansen zijn aannames. De Nederlandse
regels rond bedenktijd en de voorwaarden van winkels en affiliatenetwerken
zijn nog niet nagelezen.
