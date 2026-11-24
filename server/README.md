# Server: de prijsmotor

- `adapters/` één bestand per winkel, met dezelfde interface. Alle vijf
  gebruiken nu de gedeelde JSON-LD-lezer (`shared.ts`, `jsonld.ts`).
  `http.ts` haalt pagina's netjes op: robots.txt, vijf seconden per winkel,
  User-Agent met contactadres.
- `jobs/` de dagelijkse controle (`daily.ts`), de meldingsregels
  (`detect.ts`), opslag in Supabase en pushmeldingen via APNs.
- `supabase/migrations/` het databaseschema.
- `supabase/functions/` Edge Functions: `lookup` (link naar product en prijs)
  en `sync` (aankopen van de app heen, stand terug).
- `tests/` tests, met voorbeeldpagina's in `tests/fixtures/`.

## Testen

```bash
cd server && npm install && npm test
```

```bash
cd server && npm run typecheck
```

## Dagelijkse controle draaien

Omgevingsvariabelen: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`,
`PRIJSWACHT_CONTACT` (bijvoorbeeld `mailto:jij@voorbeeld.nl`). Voor echte
pushmeldingen ook `APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID` en
`APNS_PRODUCTION=1`; zonder die sleutels worden meldingen alleen gelogd.

```bash
cd server && npm run daily
```

```bash
cd server && npm run recheck
```

`daily` draait elke dag om 06:00, `recheck` ruim een uur later. De tweede
controle bevestigt een daling; pas dan gaat de melding uit.

## Nog niet uitgevoerd

Niets hiervan heeft tegen een echt Supabase-project, tegen Apple of tegen een
echte winkel gedraaid. De Edge Functions importeren code uit `adapters/` en
`jobs/`, buiten de map `supabase/functions`; controleer bij het uitrollen of
de Supabase-CLI die bestanden meeneemt.
