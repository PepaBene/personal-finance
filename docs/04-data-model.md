# Data Model

**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform
**Engine:** **SQLite** on every device, accessed via **Drift** (type-safe, reactive `Stream` queries); encrypted at rest (SQLCipher on native, app-level on web OPFS). Mirrored to **Supabase Postgres** in the cloud and kept in sync by **PowerSync**.

---

## 1. Entity overview (ERD)

The logical entities are unchanged from the original local-only design; they are now implemented as **Drift tables** over SQLite and mirrored to Postgres.

```
Account ──< Transaction >── Merchant
                 │  │
                 │  └──< Attachment (Document)
                 │
                 └──< LineItem >── Category (self-ref parent)
                          │
                          └──< LineItemTag >── Tag

Category ──< Budget
Currency ──< ExchangeRate
Transaction ── RecurringTemplate (optional source)
CategorizationRule  (standalone, applied at parse time)
Setting (key/value)
```

Legend: `A ──< B` = one-to-many (A is parent). `>──` = many-to-one.

> **Drift conventions (apply to every table below):**
> - **Ids are UUID strings** (`TextColumn`, generated client-side) so rows can be created offline and merged across devices without collision.
> - **Money** is stored as a **TEXT decimal string** (full precision, no float) via a Drift `TypeConverter` mapping to the Dart `Decimal` type. *(Alternative considered: scaled-integer minor units. Rejected to keep arbitrary-precision and avoid per-currency scale bugs — ADR-005.)*
> - **Enums** map to TEXT (or INT index) via `TypeConverter`s; **dates/times** are stored UTC as ISO-8601 TEXT (or epoch millis) via converters.
> - **Every synced table carries the sync columns** in [§1.1](#11-sync-columns-every-synced-table).
> - Tables are defined with Drift `Table` classes; DAOs expose reactive `Stream<List<T>>` queries that drive the UI.

### 1.1 Sync columns (every synced table)

PowerSync convergence requires uniform metadata on every synced row:

| Column | Drift type | Notes |
|--------|-----------|-------|
| `id` | `text()` (UUID) | Primary key, client-generated, globally unique. |
| `userId` | `text()` | Owner; the tenant key. Drives Row-Level Security and PowerSync sync rules. |
| `updatedAt` | `dateTime()` (UTC) | Last-write timestamp; the conflict-resolution key. Set on every write. |
| `deleted` | `boolean()` default `false` | **Tombstone** for soft-delete. Deletes set this `true` so the deletion propagates; never hard-delete synced rows on device. |
| `version` | `integer()` default `0` | Per-row clock; bumped on each write. Used to detect concurrent edits and break ties. |

`Setting` and other purely device-local rows may omit `userId`/`version`; all user data tables include the full set.

## 2. Core entities

### 2.1 Transaction (header)
A money event. Holds totals; detail lives in line items.

| Column | Drift type → Dart | Notes |
|--------|-------------------|-------|
| id | `text()` UUID PK | client-generated |
| type | `text()` enum → `TxType` | Expense, Income, Transfer |
| date | `dateTime()` | event date (drives FX rate & reporting period) |
| merchantId | `text()?` FK → Merchant | nullable for income/transfer |
| accountId | `text()` FK → Account | source account |
| counterAccountId | `text()?` FK → Account | only for Transfer (destination) |
| currencyCode | `text()` FK → Currency | original currency |
| totalAmount | `text()` → `Decimal` (Money) | original currency, signed by Type convention |
| baseAmount | `text()` → `Decimal` (Money) | converted to base currency (cached) |
| exchangeRate | `text()` → `Decimal` | rate used (orig→base) on `date` |
| taxAmount | `text()?` → `Decimal` | nullable |
| source | `text()` enum → `TxSource` | Manual, Scan, Import, Recurring |
| recurringTemplateId | `text()?` FK | nullable |
| note | `text()?` | nullable |
| status | `text()` enum → `TxStatus` | Active, Deleted (mirrors `deleted` tombstone) |
| createdAt | `dateTime()` | audit |
| + **sync columns** | see [§1.1](#11-sync-columns-every-synced-table) | `id`, `userId`, `updatedAt`, `deleted`, `version` |

**Invariants:** Σ(LineItem.lineAmount) == totalAmount (within rounding tolerance). Transfers do not affect income/expense aggregates. The Σ invariant is re-validated on-device after a sync merge.

### 2.2 LineItem (detail)
One purchased item / charge. **This is where categorization & multi-category splitting happens** — a transaction with line items in different categories *is* a split bill.

| Column | Drift type → Dart | Notes |
|--------|-------------------|-------|
| id | `text()` UUID PK | |
| transactionId | `text()` FK → Transaction | cascade delete (local); children keyed to parent for sync |
| description | `text()` | item text (from OCR or manual) |
| quantity | `text()` → `Decimal` | default 1 |
| unitPrice | `text()?` → `Decimal` | nullable |
| lineAmount | `text()` → `Decimal` (Money) | original currency |
| categoryId | `text()` FK → Category | required |
| taxRate | `text()?` → `Decimal` | nullable |
| ocrConfidence | `real()?` | 0–1, nullable (scan provenance) |
| sortOrder | `integer()` | display order |
| + **sync columns** | see [§1.1](#11-sync-columns-every-synced-table) | |

### 2.3 Category (hierarchical)
| Column | Drift type → Dart | Notes |
|--------|-------------------|-------|
| id | `text()` UUID PK | |
| parentId | `text()?` FK → Category | nullable (root) |
| name | `text()` | |
| kind | `text()` enum → `CategoryKind` | Expense, Income |
| icon | `text()` | glyph/asset key |
| colorHex | `text()` | for charts |
| isArchived | `boolean()` | hide without deleting history |
| sortOrder | `integer()` | |
| + **sync columns** | see [§1.1](#11-sync-columns-every-synced-table) | |

Default seed set: Groceries, Dining, Food (parent), Utilities, Housing/Rent, Transport, Fuel, Health, Leisure/Fun, Entertainment, Shopping, Clothing, Subscriptions, Education, Gifts, Travel, Fees, Taxes, Salary (Income), Other Income, Misc.

### 2.4 Merchant / Payee
| Column | Drift type → Dart | Notes |
|--------|-------------------|-------|
| id | `text()` UUID PK | |
| name | `text()` | canonical |
| defaultCategoryId | `text()?` FK → Category | learned suggestion |
| aliases | `text()?` (JSON) → `List<String>` | OCR/name variants for matching |
| notes | `text()?` | |
| + **sync columns** | see [§1.1](#11-sync-columns-every-synced-table) | |

### 2.5 Account
| Column | Drift type → Dart | Notes |
|--------|-------------------|-------|
| id | `text()` UUID PK | |
| name | `text()` | |
| kind | `text()` enum → `AccountKind` | Cash, Bank, Card, Other |
| currencyCode | `text()` FK → Currency | account's native currency |
| openingBalance | `text()` → `Decimal` (Money) | |
| isArchived | `boolean()` | |
| + **sync columns** | see [§1.1](#11-sync-columns-every-synced-table) | |

Current balance = openingBalance + signed sum of transactions/transfers (computed via SQL aggregation in Drift, optionally cached).

### 2.6 Attachment (Document)
| Column | Drift type → Dart | Notes |
|--------|-------------------|-------|
| id | `text()` UUID PK | |
| transactionId | `text()?` FK → Transaction | nullable until linked |
| docType | `text()` enum → `DocType` | Receipt, Invoice, Bill, Paycheck, Other |
| fileName | `text()` | original name |
| storageKey | `text()?` | Supabase Storage object key (per-user bucket) |
| localCachePath | `text()?` | decrypted/encrypted local cache path |
| encNonce | `text()?` | AES-256-GCM nonce/IV for the client-side-encrypted blob |
| sha256 | `text()` | dedupe / integrity |
| ocrText | `text()?` | full extracted text (searchable; stored in DB) |
| scanStatus | `text()` enum → `ScanStatus` | Pending, Parsed, Reviewed, Failed |
| pageCount | `integer()` | |
| importedAt | `dateTime()` | |
| + **sync columns** | see [§1.1](#11-sync-columns-every-synced-table) | |

Blob bytes are **not** stored in the DB; they live as **client-side-encrypted objects in Supabase Storage** with a local cache (ADR-004). Metadata, OCR text, integrity hash, and the encryption nonce live in this row.

### 2.7 Tag & LineItemTag
- `Tag(id UUID, name, colorHex, + sync columns)`
- `LineItemTag(id UUID, lineItemId FK, tagId FK, + sync columns)` — many-to-many. (Tags complement categories; a category is the single primary bucket, tags are cross-cutting labels.) The join row carries its own `id` and sync columns so the relationship converges independently.

## 3. Multi-currency model

### 3.1 Currency
`Currency(code TEXT PK [ISO 4217, e.g. CZK/EUR/USD], symbol, decimalDigits INT, name)`. Currency reference data syncs to all devices.

### 3.2 ExchangeRate (historical)
`ExchangeRate(id UUID PK, fromCode FK, toCode FK, rate TEXT→Decimal, date, source enum{Manual,Fetched}, + sync columns)`. Unique on `(fromCode, toCode, date)`.

### 3.3 Conversion rules
1. Each transaction stores **original** currency + amount.
2. On save, the app computes `baseAmount = round(totalAmount × rate(orig→base, date))` and caches the `exchangeRate`.
3. Rate lookup picks the rate for `date`; if absent, the **most recent rate on or before** `date`; if none, prompt the user (offline-safe — manual entry).
4. Changing the base currency triggers a recompute of cached `baseAmount` for all transactions (background isolate job).
5. All analytics aggregate on `baseAmount`.

### 3.4 Money handling (no float)
- Stored as a **TEXT decimal string** in SQLite, mapped to Dart **`Decimal`** (`decimal` package) via a Drift `TypeConverter`.
- A **`Money`** value object (`amount: Decimal` + `currencyCode`) guards arithmetic; mixing currencies without a rate throws.
- Rounding: **banker's rounding (round-half-to-even)** to the currency's `decimalDigits`; applied only at persistence/display boundaries, never mid-calculation (ADR-005).

## 4. Categorization support entities

### 4.1 CategorizationRule
`CategorizationRule(id UUID, matchType enum{MerchantEquals, DescriptionContains, Regex}, pattern TEXT, categoryId FK, priority INT, isEnabled BOOL, + sync columns)`.
Applied in priority order during scan parsing and as a "re-apply rules" action. First match wins (configurable).

### 4.2 Budget
`Budget(id UUID, categoryId FK, period enum{Monthly}, amount TEXT→Decimal, currencyCode FK, startMonth, isActive, + sync columns)`.

### 4.3 RecurringTemplate
`RecurringTemplate(id UUID, type, merchantId, accountId, currencyCode, amount TEXT→Decimal, categoryId(default), frequency enum{Weekly,Monthly,Yearly}, nextDate, isActive, + sync columns)`. Generates draft transactions on/after `nextDate`.

### 4.4 Setting
`Setting(key TEXT PK, value TEXT)` — base currency, locale, theme, auto-lock timeout, OCR engine/language, etc. User-scoped settings sync (with sync columns); device-local prefs (e.g. selected camera) stay local.

## 5. Cloud schema / Supabase

The cloud mirrors the local model so PowerSync can stream rows in both directions.

- **Mirrored Postgres tables** — one Postgres table per synced Drift table, same columns (Postgres-native types: `uuid` for ids, `timestamptz` for `updatedAt`, `numeric` or `text` for money preserving the decimal string, `boolean` for `deleted`, `integer` for `version`). The decimal-as-text convention is preserved end-to-end to avoid precision drift.
- **Row-Level Security (RLS)** — every table has RLS enabled with policies keyed to `auth.uid()`:
  ```sql
  alter table public.transactions enable row level security;
  create policy "owner can read"   on public.transactions for select using (user_id = auth.uid());
  create policy "owner can write"  on public.transactions for insert with check (user_id = auth.uid());
  create policy "owner can update" on public.transactions for update using (user_id = auth.uid()) with check (user_id = auth.uid());
  ```
  This enforces **tenant isolation** server-side; a device can only ever read/write its owner's rows.
- **Supabase Storage** — attachments live in a per-user bucket as **client-side-encrypted blobs** (AES-256-GCM, key derived from the user passphrase via Argon2id — see [09-security-privacy.md](09-security-privacy.md)). Storage RLS restricts object paths to `auth.uid()`. The server never sees plaintext attachments.
- **PowerSync sync rules** — per-user rules stream only the authenticated user's rows to that user's devices, e.g.:
  ```yaml
  bucket_definitions:
    user_data:
      parameters: select request.user_id() as user_id
      data:
        - select * from transactions where user_id = bucket.user_id and deleted = false
        - select * from line_items   where user_id = bucket.user_id and deleted = false
        # ... one line per synced table
  ```
- **Account deletion / export** — because data is now hosted, GDPR right-to-erasure and portability apply: deletion purges Postgres rows + Storage objects for the `user_id`; export bundles the user's rows and decrypted attachments. See [09-security-privacy.md](09-security-privacy.md).

## 6. Conflict resolution

- **Per-row last-write-wins on `updatedAt` (UTC).** When two devices edit the same row offline, the row with the newer `updatedAt` wins on merge; `version` breaks ties and detects concurrency. Timestamps are UTC to avoid timezone skew; large clock skew is mitigated by server-stamped receipt where available.
- **Tombstones over hard deletes.** Deletes set `deleted = true` (and `Transaction.status = Deleted`) so the deletion converges across devices; rows are physically purged only after the retention window by the purge job.
- **Children keyed to parents.** `LineItem`s and `LineItemTag`s converge against their parent `Transaction`. If a parent re-arrives after a delete elsewhere, its children re-anchor; orphaned children are reconciled by the device after merge, and the Σ(line amounts) == totalAmount invariant is re-validated.
- **Granularity.** LWW is per-row, so concurrent edits to *different* rows (e.g. one device edits the header, another adds a line item) both survive and combine.

## 7. Indexing & integrity

- **Indexes** (local Drift + mirrored in Postgres): `Transaction(date)`, `Transaction(merchantId)`, `Transaction(accountId)`, `LineItem(transactionId)`, `LineItem(categoryId)`, `Attachment(sha256)`, `ExchangeRate(fromCode,toCode,date)`, plus `(userId, updatedAt)` on synced tables to accelerate sync scans.
- **Foreign keys** enforced locally (`PRAGMA foreign_keys = ON`); enforced in Postgres natively.
- **Cascade:** deleting a Transaction cascades LineItems & LineItemTags locally; for sync, cascades are expressed as tombstones on the children.
- **Soft delete + purge:** `deleted` tombstone enables undo and cross-device deletion; a retention-window purge job removes tombstoned rows from device and cloud.
- **WAL:** `PRAGMA journal_mode = WAL` for crash-safe concurrent reads on native SQLite.

## 8. Migrations & versioning

- **Drift schema versions** — the database `schemaVersion` is bumped per change; migration steps are defined in Drift's `MigrationStrategy` (`onUpgrade` with stepwise `from → to` migrations). The schema is also exported (Drift schema dumps) so migrations are tested against prior versions in CI.
- **Cloud migrations** — corresponding Postgres migrations (via Supabase migrations) keep the mirrored schema and RLS policies in lockstep; PowerSync sync rules are updated alongside. Schema changes are rolled out cloud-first, then client, to keep older clients syncing.
- **Pre-migration local snapshot** — before any local migration, the app writes an automatic snapshot (copy of the encrypted DB file) to `backups/auto/` so an upgrade can be rolled back. See [09-security-privacy.md](09-security-privacy.md) §backups. Cloud sync provides an additional recovery path.

## 9. Example: a multi-category supermarket receipt

```
Transaction { id=UUID, userId=UUID, type=Expense, date=2026-06-08, merchant="Albert",
              currency=CZK, total="842.00", baseAmount(EUR)="33.68", rate="0.04",
              updatedAt=2026-06-08T17:12:00Z, deleted=false, version=1 }
  LineItem { "Milk 1L x2",  amount="49.80",  category=Groceries }
  LineItem { "Dish soap",   amount="89.90",  category=Household }
  LineItem { "Beer 6-pack", amount="149.40", category=Alcohol  }
  LineItem { "Bread",       amount="34.90",  category=Groceries }
  ... Σ line amounts == 842.00  ✓   (re-validated on-device after any sync merge)
  Attachment { Receipt image → AES-256-GCM blob in Supabase Storage,
               ocrText, sha256, scanStatus=Reviewed }
```

This single record satisfies FR-CAT-04 (multi-category split) and FR-SCAN-05/08, and — with the sync columns and the encrypted Storage attachment — converges across all of the user's devices.
