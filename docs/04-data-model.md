# Data Model

**Version:** 0.1 · **Date:** 2026-06-09
**Engine:** SQLite (SQLCipher-encrypted), accessed via EF Core 10.

---

## 1. Entity overview (ERD)

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

## 2. Core entities

### 2.1 Transaction (header)
A money event. Holds totals; detail lives in line items.

| Column | Type | Notes |
|--------|------|-------|
| Id | GUID/INTEGER PK | |
| Type | enum | Expense, Income, Transfer |
| Date | DATE | event date (drives FX rate & reporting period) |
| MerchantId | FK → Merchant | nullable for income/transfer |
| AccountId | FK → Account | source account |
| CounterAccountId | FK → Account | only for Transfer (destination) |
| CurrencyCode | FK → Currency | original currency |
| TotalAmount | DECIMAL(19,4) | original currency, signed by Type convention |
| BaseAmount | DECIMAL(19,4) | converted to base currency (cached) |
| ExchangeRate | DECIMAL(19,8) | rate used (orig→base) on Date |
| TaxAmount | DECIMAL(19,4) | nullable |
| Source | enum | Manual, Scan, Import, Recurring |
| RecurringTemplateId | FK | nullable |
| Note | TEXT | nullable |
| Status | enum | Active, Deleted (soft) |
| CreatedAt / UpdatedAt | DATETIME | audit |

**Invariants:** Σ(LineItem.LineAmount) == TotalAmount (within rounding tolerance). Transfers do not affect income/expense aggregates.

### 2.2 LineItem (detail)
One purchased item / charge. **This is where categorization & multi-category splitting happens** — a transaction with line items in different categories *is* a split bill.

| Column | Type | Notes |
|--------|------|-------|
| Id | PK | |
| TransactionId | FK → Transaction | cascade delete |
| Description | TEXT | item text (from OCR or manual) |
| Quantity | DECIMAL(19,4) | default 1 |
| UnitPrice | DECIMAL(19,4) | nullable |
| LineAmount | DECIMAL(19,4) | original currency |
| CategoryId | FK → Category | required |
| TaxRate | DECIMAL(9,4) | nullable |
| OcrConfidence | REAL | 0–1, nullable (scan provenance) |
| SortOrder | INT | display order |

### 2.3 Category (hierarchical)
| Column | Type | Notes |
|--------|------|-------|
| Id | PK | |
| ParentId | FK → Category | nullable (root) |
| Name | TEXT | |
| Kind | enum | Expense, Income |
| Icon | TEXT | glyph/asset key |
| ColorHex | TEXT | for charts |
| IsArchived | BOOL | hide without deleting history |
| SortOrder | INT | |

Default seed set: Groceries, Dining, Food (parent), Utilities, Housing/Rent, Transport, Fuel, Health, Leisure/Fun, Entertainment, Shopping, Clothing, Subscriptions, Education, Gifts, Travel, Fees, Taxes, Salary (Income), Other Income, Misc.

### 2.4 Merchant / Payee
| Column | Type | Notes |
|--------|------|-------|
| Id | PK | |
| Name | TEXT | canonical |
| DefaultCategoryId | FK → Category | learned suggestion |
| Aliases | TEXT (JSON) | OCR/name variants for matching |
| Notes | TEXT | |

### 2.5 Account
| Column | Type | Notes |
|--------|------|-------|
| Id | PK | |
| Name | TEXT | |
| Kind | enum | Cash, Bank, Card, Other |
| CurrencyCode | FK → Currency | account's native currency |
| OpeningBalance | DECIMAL(19,4) | |
| IsArchived | BOOL | |

Current balance = OpeningBalance + signed sum of transactions/transfers (computed, optionally cached).

### 2.6 Attachment (Document)
| Column | Type | Notes |
|--------|------|-------|
| Id | PK | |
| TransactionId | FK → Transaction | nullable until linked |
| DocType | enum | Receipt, Invoice, Bill, Paycheck, Other |
| FileName | TEXT | original name |
| StoragePath | TEXT | encrypted file path (or null if BLOB) |
| Blob | BLOB | optional inline storage (ADR-004) |
| Sha256 | TEXT | dedupe / integrity |
| OcrText | TEXT | full extracted text (searchable) |
| ScanStatus | enum | Pending, Parsed, Reviewed, Failed |
| PageCount | INT | |
| ImportedAt | DATETIME | |

### 2.7 Tag & LineItemTag
- `Tag(Id, Name, ColorHex)`
- `LineItemTag(LineItemId FK, TagId FK)` — many-to-many. (Tags complement categories; a category is the single primary bucket, tags are cross-cutting labels.)

## 3. Multi-currency model

### 3.1 Currency
`Currency(Code PK [ISO 4217, e.g. CZK/EUR/USD], Symbol, DecimalDigits, Name)`.

### 3.2 ExchangeRate (historical)
`ExchangeRate(Id, FromCode FK, ToCode FK, Rate DECIMAL(19,8), Date DATE, Source enum{Manual,Fetched})`
Unique on (FromCode, ToCode, Date).

### 3.3 Conversion rules
1. Each transaction stores **original** currency + amount.
2. On save, the app computes `BaseAmount = round(TotalAmount × rate(orig→base, Date))` and caches `ExchangeRate`.
3. Rate lookup picks the rate for `Date`; if absent, the **most recent rate on or before** `Date`; if none, prompt the user.
4. Changing the base currency triggers a recompute of cached `BaseAmount` for all transactions (background job).
5. All analytics aggregate on `BaseAmount`.

### 3.4 Money handling (no float)
- Stored as `DECIMAL` in SQLite, mapped to C# `decimal`.
- A `Money` value object (`Amount` + `CurrencyCode`) guards arithmetic; mixing currencies without a rate throws.
- Rounding: **banker's rounding (ToEven)** to the currency's `DecimalDigits`; rounding applied only at persistence/display boundaries, not mid-calculation.

## 4. Categorization support entities

### 4.1 CategorizationRule
`Id, MatchType enum{MerchantEquals, DescriptionContains, Regex}, Pattern TEXT, CategoryId FK, Priority INT, IsEnabled BOOL`.
Applied in priority order during scan parsing and as a "re-apply rules" action. First match wins (configurable).

### 4.2 Budget
`Id, CategoryId FK, Period enum{Monthly}, Amount DECIMAL(19,4), CurrencyCode FK, StartMonth, IsActive`.

### 4.3 RecurringTemplate
`Id, Type, MerchantId, AccountId, CurrencyCode, Amount, CategoryId(default), Frequency enum{Weekly,Monthly,Yearly}, NextDate, IsActive`. Generates draft transactions on/after `NextDate`.

### 4.4 Setting
`Key TEXT PK, Value TEXT` — base currency, locale, theme, auto-lock timeout, OCR engine/language, etc.

## 5. Indexing & integrity

- Indexes: `Transaction(Date)`, `Transaction(MerchantId)`, `Transaction(AccountId)`, `LineItem(TransactionId)`, `LineItem(CategoryId)`, `Attachment(Sha256)`, `ExchangeRate(FromCode,ToCode,Date)`.
- Foreign keys enforced (`PRAGMA foreign_keys = ON`).
- Cascade: deleting a Transaction cascades LineItems & LineItemTags; Attachments are detached/removed per policy.
- Soft delete on Transaction (`Status=Deleted`) for undo; a purge job removes after retention window.
- `PRAGMA journal_mode = WAL` for crash-safe concurrent reads.

## 6. Migrations & versioning

- EF Core migrations; a `SchemaVersion` recorded in `Setting`.
- Before any migration, the app writes an automatic local snapshot (copy of the DB file) to `backups/auto/` so an upgrade can be rolled back. See [09](09-security-privacy.md) §backups.

## 7. Example: a multi-category supermarket receipt

```
Transaction { Type=Expense, Date=2026-06-08, Merchant="Albert",
              Currency=CZK, Total=842.00, BaseAmount(EUR)=33.68, Rate=0.04 }
  LineItem { "Milk 1L x2", Amount=49.80,  Category=Groceries }
  LineItem { "Dish soap",  Amount=89.90,  Category=Household }
  LineItem { "Beer 6-pack",Amount=149.40, Category=Alcohol  }
  LineItem { "Bread",      Amount=34.90,  Category=Groceries }
  ... Σ line amounts == 842.00  ✓
  Attachment { Receipt image, OcrText, ScanStatus=Reviewed }
```

This single record satisfies FR-CAT-04 (multi-category split) and FR-SCAN-05/08.
