-- Ledgerly — Phase 1 cloud schema (docs/04). Adds the full MVP model mirroring
-- the local Drift tables, with Row-Level Security keyed to auth.uid() on every
-- table (FR-AUTH-03, FR-SEC-06). Money stays TEXT decimal end-to-end (docs/04
-- §3.4). `currencies` is intentionally absent: it is local-only reference data.

-- New header columns on transactions (docs/04 §2.1).
alter table public.transactions add column if not exists exchange_rate text;
alter table public.transactions add column if not exists tax_amount    text;

-- Helper to keep every synced table's RLS identical and owner-scoped.
create or replace function public.ledgerly_owner_policies(tbl regclass)
returns void language plpgsql as $$
begin
  execute format('alter table %s enable row level security', tbl);
  execute format($f$create policy "owner can select" on %s for select using (user_id = auth.uid())$f$, tbl);
  execute format($f$create policy "owner can insert" on %s for insert with check (user_id = auth.uid())$f$, tbl);
  execute format($f$create policy "owner can update" on %s for update using (user_id = auth.uid()) with check (user_id = auth.uid())$f$, tbl);
end;
$$;

-- line_items ----------------------------------------------------------------
create table if not exists public.line_items (
  id              uuid        primary key,
  user_id         uuid        not null default auth.uid(),
  transaction_id  uuid        not null,
  description     text        not null,
  quantity        text        not null,
  unit_price      text,
  line_amount     text        not null,
  category_id     uuid        not null,
  tax_rate        text,
  ocr_confidence  real,
  sort_order      integer     not null default 0,
  updated_at      timestamptz not null,
  deleted         boolean     not null default false,
  version         integer     not null default 0
);
create index if not exists idx_li_transaction on public.line_items (transaction_id);
create index if not exists idx_li_category    on public.line_items (category_id);
select public.ledgerly_owner_policies('public.line_items');

-- categories ----------------------------------------------------------------
create table if not exists public.categories (
  id          uuid        primary key,
  user_id     uuid        not null default auth.uid(),
  parent_id   uuid,
  name        text        not null,
  kind        text        not null,
  icon        text        not null default 'category',
  color_hex   text        not null default '#4E79A7',
  is_archived boolean     not null default false,
  sort_order  integer     not null default 0,
  updated_at  timestamptz not null,
  deleted     boolean     not null default false,
  version     integer     not null default 0
);
select public.ledgerly_owner_policies('public.categories');

-- accounts ------------------------------------------------------------------
create table if not exists public.accounts (
  id              uuid        primary key,
  user_id         uuid        not null default auth.uid(),
  name            text        not null,
  kind            text        not null,
  currency_code   text        not null,
  opening_balance text        not null,
  is_archived     boolean     not null default false,
  updated_at      timestamptz not null,
  deleted         boolean     not null default false,
  version         integer     not null default 0
);
select public.ledgerly_owner_policies('public.accounts');

-- merchants -----------------------------------------------------------------
create table if not exists public.merchants (
  id                  uuid        primary key,
  user_id             uuid        not null default auth.uid(),
  name                text        not null,
  default_category_id uuid,
  aliases             text        not null default '[]',
  notes               text,
  updated_at          timestamptz not null,
  deleted             boolean     not null default false,
  version             integer     not null default 0
);
select public.ledgerly_owner_policies('public.merchants');

-- tags + line_item_tags -----------------------------------------------------
create table if not exists public.tags (
  id         uuid        primary key,
  user_id    uuid        not null default auth.uid(),
  name       text        not null,
  color_hex  text        not null default '#BAB0AC',
  updated_at timestamptz not null,
  deleted    boolean     not null default false,
  version    integer     not null default 0
);
select public.ledgerly_owner_policies('public.tags');

create table if not exists public.line_item_tags (
  id           uuid        primary key,
  user_id      uuid        not null default auth.uid(),
  line_item_id uuid        not null,
  tag_id       uuid        not null,
  updated_at   timestamptz not null,
  deleted      boolean     not null default false,
  version      integer     not null default 0
);
select public.ledgerly_owner_policies('public.line_item_tags');

-- exchange_rates ------------------------------------------------------------
create table if not exists public.exchange_rates (
  id         uuid        primary key,
  user_id    uuid        not null default auth.uid(),
  from_code  text        not null,
  to_code    text        not null,
  rate       text        not null,
  date       timestamptz not null,
  source     text        not null default 'manual',
  updated_at timestamptz not null,
  deleted    boolean     not null default false,
  version    integer     not null default 0
);
create unique index if not exists idx_fx_unique
  on public.exchange_rates (user_id, from_code, to_code, date);
select public.ledgerly_owner_policies('public.exchange_rates');

-- settings (id embeds the user, so the key is globally unique) ---------------
create table if not exists public.settings (
  id         text        primary key,
  user_id    uuid        not null default auth.uid(),
  value      text        not null,
  updated_at timestamptz not null,
  deleted    boolean     not null default false,
  version    integer     not null default 0
);
select public.ledgerly_owner_policies('public.settings');
