# Fase 0: de prijsstudie

Meet elke dag de prijs van een vaste lijst producten en beantwoordt daarmee
poort 1: daalt minstens 1 op de 20 producten binnen 30 dagen met minstens €10?

Nodig: Node 22.18 of nieuwer. Er zijn geen pakketten om te installeren.

## 1. Productlijst

Kopieer `products.example.csv` naar `products.csv` en vul hem met ongeveer
300 producten bij de vijf winkels (bol, coolblue, mediamarkt, amazon,
zalando). Kolommen: `shop,url,ean,categorie`. Gebruik de link van de exacte
variant (kleur, opslag) en de EAN als je die weet; de meting slaat een product
over als de EAN op de pagina anders is.

## 2. Controleer of het per winkel werkt

```bash
PRIJSWACHT_CONTACT=mailto:jij@voorbeeld.nl node study/check.ts
```

Per winkel worden twee producten opgehaald. Je ziet of robots.txt het toestaat
en of de prijs leesbaar is. Je contactadres komt in de User-Agent.

## 3. Elke dag meten

```bash
PRIJSWACHT_CONTACT=mailto:jij@voorbeeld.nl node study/run.ts
```

De prijzen komen in `study/prijsstudie.sqlite` (tabel `prijzen`), mislukte
regels met de reden in tabel `fouten`. Per winkel zit er minstens vijf
seconden tussen twee verzoeken, dus 300 producten duren ongeveer vijf minuten.
Twee keer draaien op één dag is veilig: wat al gemeten is wordt overgeslagen.

Dagelijks om 06:00 met cron (pas het pad en het adres aan):

```
0 6 * * * cd /pad/naar/Prijswacht- && PRIJSWACHT_CONTACT=mailto:jij@voorbeeld.nl node study/run.ts >> study/run.log 2>&1
```

## 4. Analyse

```bash
node study/analyse.ts
```

Neemt elke dag als fictieve koopdatum en kijkt naar de grootste daling binnen
14 en 30 dagen daarna, per winkel en per categorie. Het aandeel koopdagen is
de eerlijkste schatting van de trefkans; het aandeel producten is het getal
van poort 1.

## Echte pagina's opslaan voor de tests

```bash
PRIJSWACHT_CONTACT=mailto:jij@voorbeeld.nl node study/save-fixture.ts "https://www.voorbeeld.nl/product"
```

Controleer daarna het `.expected.json`-bestand met de hand tegen de pagina.
