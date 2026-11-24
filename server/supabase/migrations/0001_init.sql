-- Prijswacht: eerste schema. Bedragen zijn altijd gehele centen.
-- Alle tabellen staan achter row level security zonder policies: alleen de
-- service-role-sleutel (Edge Functions en de dagelijkse taak) kan erbij.

create table shops (
  id text primary key,
  name text not null,
  country text not null default 'NL',
  return_days integer not null default 14,
  return_cost_cents integer,
  contact_url text,
  contact_email text,
  price_guarantee boolean not null default false,
  verified boolean not null default false
);

create table products (
  ean text primary key,
  title text,
  image_url text
);

-- Prijsgeschiedenis: één regel per meting.
create table offers (
  id bigint generated always as identity primary key,
  url text not null,
  shop_id text not null,
  ean text,
  price_cents integer not null check (price_cents > 0),
  currency text not null default 'EUR',
  in_stock boolean not null,
  is_new boolean not null,
  seller text,
  observed_at timestamptz not null default now()
);
create index offers_url_observed_at on offers (url, observed_at desc);
create index offers_ean_observed_at on offers (ean, observed_at desc);

-- Een installatie van de app. Er zijn geen accounts: het id is een
-- willekeurig UUID dat de app zelf maakt en dat als sleutel dient.
create table installs (
  id uuid primary key,
  threshold_cents integer not null default 1000 check (threshold_cents > 0),
  apns_token text,
  created_at timestamptz not null default now(),
  seen_at timestamptz not null default now()
);

-- Van een aankoop bewaren we alleen product, prijs, winkel en datum.
create table purchases (
  id uuid primary key,
  install_id uuid not null references installs (id) on delete cascade,
  title text not null,
  url text,
  ean text,
  shop_id text not null,
  shop_name text not null,
  paid_cents integer not null check (paid_cents > 0),
  purchase_date date not null,
  return_last_day date not null,
  archived boolean not null default false,
  current_cents integer,
  checked_at timestamptz,
  pending_cents integer,
  pending_seen_at timestamptz,
  confirmed_cents integer,
  created_at timestamptz not null default now()
);
create index purchases_install on purchases (install_id);
create index purchases_watch on purchases (return_last_day) where not archived and url is not null;

create table alerts (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references purchases (id) on delete cascade,
  new_cents integer not null,
  drop_cents integer not null,
  route text not null,
  created_at timestamptz not null default now(),
  unique (purchase_id, new_cents)
);

-- Gelukt of Geweigerd per route: de bron voor het slagingspercentage per winkel.
create table outcomes (
  id uuid primary key,
  install_id uuid not null references installs (id) on delete cascade,
  purchase_id uuid,
  shop_id text not null,
  route text not null check (route in ('askDifference', 'returnAndReorder', 'priceGuarantee')),
  succeeded boolean not null,
  amount_cents integer not null default 0,
  decided_at timestamptz not null
);
create index outcomes_shop on outcomes (shop_id, route);

create table price_failures (
  id bigint generated always as identity primary key,
  url text not null,
  shop_id text,
  reason text not null,
  detail text,
  observed_at timestamptz not null default now()
);

alter table shops enable row level security;
alter table products enable row level security;
alter table offers enable row level security;
alter table installs enable row level security;
alter table purchases enable row level security;
alter table alerts enable row level security;
alter table outcomes enable row level security;
alter table price_failures enable row level security;
