-- Ledgerly — Phase 4 performance indexes (NFR-01/02, docs/04 §7). Date drives
-- every analytics range filter; index it (and the user_id+date composite) to
-- keep aggregate scans fast at scale. The monthly rollup cache is a local-only
-- derived table and is intentionally NOT mirrored to Postgres.

create index if not exists idx_tx_date on public.transactions (date);
create index if not exists idx_tx_user_date
  on public.transactions (user_id, date);
