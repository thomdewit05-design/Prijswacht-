// Dagelijkse prijscontrole. Gebruik:
//   node jobs/run.ts            volledige controle (elke dag om 06:00)
//   node jobs/run.ts --recheck  tweede controle van wachtende dalingen (07:15)
import { PoliteFetcher } from "../adapters/http.ts";
import { ApnsSender, LogSender } from "./apns.ts";
import { runDaily } from "./daily.ts";
import { SupabaseStore } from "./supabase-store.ts";

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    console.error(`Omgevingsvariabele ${name} ontbreekt. Zie server/README.md.`);
    process.exit(2);
  }
  return value;
}

const store = new SupabaseStore(required("SUPABASE_URL"), required("SUPABASE_SERVICE_ROLE_KEY"));
const fetcher = new PoliteFetcher({ userAgent: `Prijswacht/0.1 (+${required("PRIJSWACHT_CONTACT")})` });
const push = process.env.APNS_KEY_P8
  ? new ApnsSender({
      privateKey: process.env.APNS_KEY_P8,
      keyId: required("APNS_KEY_ID"),
      teamId: required("APNS_TEAM_ID"),
      topic: process.env.APNS_TOPIC ?? "nl.prijswacht.app",
      production: process.env.APNS_PRODUCTION === "1",
    })
  : new LogSender();

const result = await runDaily({
  store,
  fetcher,
  push,
  recheckOnly: process.argv.includes("--recheck"),
  log: (line) => console.log(line),
});
console.log(`Klaar: ${result.checked} gecontroleerd, ${result.failed} mislukt, ${result.alerts} meldingen.`);
