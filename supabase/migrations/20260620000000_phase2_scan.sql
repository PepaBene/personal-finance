-- Ledgerly — Phase 2 scan schema (docs/04 §2.6, §4.1; docs/09 §2). Adds the two
-- synced tables backing scanning: auto-categorization rules and attachment
-- metadata. Blob bytes are NOT stored here — they live as client-side-encrypted
-- objects in Supabase Storage; only metadata, OCR text, the integrity hash, and
-- the AES-256-GCM nonce are mirrored. RLS is owner-scoped like every other table
-- (reuses public.ledgerly_owner_policies from the Phase 1 migration).

-- categorization_rules (FR-CAT-05) ------------------------------------------
create table if not exists public.categorization_rules (
  id          uuid        primary key,
  user_id     uuid        not null default auth.uid(),
  match_type  text        not null,
  pattern     text        not null,
  category_id uuid        not null,
  priority    integer     not null default 0,
  is_enabled  boolean     not null default true,
  updated_at  timestamptz not null,
  deleted     boolean     not null default false,
  version     integer     not null default 0
);
create index if not exists idx_catrule_user_priority
  on public.categorization_rules (user_id, priority desc);
select public.ledgerly_owner_policies('public.categorization_rules');

-- attachments (FR-SCAN-08) --------------------------------------------------
create table if not exists public.attachments (
  id               uuid        primary key,
  user_id          uuid        not null default auth.uid(),
  transaction_id   uuid,
  doc_type         text        not null,
  file_name        text        not null,
  storage_key      text,
  local_cache_path text,
  enc_nonce        text,
  sha256           text        not null,
  ocr_text         text,
  scan_status      text        not null default 'pending',
  page_count       integer     not null default 1,
  imported_at      timestamptz not null,
  updated_at       timestamptz not null,
  deleted          boolean     not null default false,
  version          integer     not null default 0
);
create index if not exists idx_att_transaction on public.attachments (transaction_id);
create index if not exists idx_att_sha256       on public.attachments (sha256);
select public.ledgerly_owner_policies('public.attachments');
