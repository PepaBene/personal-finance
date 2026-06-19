-- Ledgerly — Phase 3 cloud schema (docs/05 §10, FR-SCAN-10). Adds the synced
-- table backing per-merchant OCR templates: learned hints (typical currency,
-- document type, and line-description→category map) that improve future
-- extraction for the same merchant. RLS is owner-scoped like every other table
-- (reuses public.ledgerly_owner_policies from the Phase 1 migration).

create table if not exists public.merchant_templates (
  id             uuid        primary key,
  user_id        uuid        not null default auth.uid(),
  merchant_key   text        not null,
  currency_code  text,
  doc_type       text,
  category_hints text        not null default '{}',
  sample_count   integer     not null default 0,
  updated_at     timestamptz not null,
  deleted        boolean     not null default false,
  version        integer     not null default 0
);
create index if not exists idx_mtpl_user_key
  on public.merchant_templates (user_id, merchant_key);
select public.ledgerly_owner_policies('public.merchant_templates');
