-- Ledgerly — Phase 3 cloud schema (docs/04 §4.2, §4.3; FR-BUD, FR-CAP-07). Adds
-- the two synced tables backing deeper analysis & budgets: per-category monthly
-- budgets and recurring transaction templates. Money stays TEXT decimal
-- end-to-end (docs/04 §3.4). RLS is owner-scoped like every other table (reuses
-- public.ledgerly_owner_policies from the Phase 1 migration).

-- budgets (FR-BUD-01) -------------------------------------------------------
create table if not exists public.budgets (
  id            uuid        primary key,
  user_id       uuid        not null default auth.uid(),
  category_id   uuid        not null,
  period        text        not null default 'monthly',
  amount        text        not null,
  currency_code text        not null,
  start_month   timestamptz not null,
  is_active     boolean     not null default true,
  updated_at    timestamptz not null,
  deleted       boolean     not null default false,
  version       integer     not null default 0
);
create index if not exists idx_budget_user_category
  on public.budgets (user_id, category_id);
select public.ledgerly_owner_policies('public.budgets');

-- recurring_templates (FR-CAP-07) ------------------------------------------
create table if not exists public.recurring_templates (
  id            uuid        primary key,
  user_id       uuid        not null default auth.uid(),
  type          text        not null,
  name          text        not null,
  account_id    uuid        not null,
  merchant_id   uuid,
  category_id   uuid        not null,
  currency_code text        not null,
  amount        text        not null,
  note          text,
  frequency     text        not null,
  next_date     timestamptz not null,
  last_run_date timestamptz,
  is_active     boolean     not null default true,
  updated_at    timestamptz not null,
  deleted       boolean     not null default false,
  version       integer     not null default 0
);
create index if not exists idx_recurring_user_next
  on public.recurring_templates (user_id, next_date);
select public.ledgerly_owner_policies('public.recurring_templates');
