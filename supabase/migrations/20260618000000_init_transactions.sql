-- Ledgerly — Phase 0 cloud schema (docs/04 §5, docs/13 §5.3).
-- Mirrors the local Drift `transactions` table and enforces tenant isolation
-- with Row-Level Security keyed to auth.uid() (FR-AUTH-03, FR-SEC-06).
--
-- Money is preserved as TEXT decimal end-to-end (docs/04 §3.4) to avoid any
-- float/precision drift between SQLite and Postgres. Dates are timestamptz.

create table if not exists public.transactions (
  id                  uuid        primary key,
  user_id             uuid        not null default auth.uid(),
  type                text        not null,
  date                timestamptz not null,
  account_id          text        not null,
  merchant_id         text,
  counter_account_id  text,
  currency_code       text        not null,
  total_amount        text        not null,
  base_amount         text        not null,
  note                text,
  source              text        not null default 'manual',
  status              text        not null default 'active',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null,
  deleted             boolean     not null default false,
  version             integer     not null default 0
);

-- Sync-scan + reporting indexes (docs/04 §7).
create index if not exists idx_tx_user_updated
  on public.transactions (user_id, updated_at);
create index if not exists idx_tx_date
  on public.transactions (date);

-- ---------------------------------------------------------------------------
-- Row-Level Security: a device can only ever read/write its owner's rows.
-- ---------------------------------------------------------------------------
alter table public.transactions enable row level security;

create policy "tx owner can select"
  on public.transactions for select
  using (user_id = auth.uid());

create policy "tx owner can insert"
  on public.transactions for insert
  with check (user_id = auth.uid());

create policy "tx owner can update"
  on public.transactions for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Deletes are tombstones (deleted = true) propagated as UPDATEs by the client;
-- hard DELETE is intentionally not granted to clients (docs/04 §6). A retention
-- purge job (service role) removes tombstoned rows after the retention window.
