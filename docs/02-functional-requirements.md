# Functional & Non-Functional Requirements

**Version:** 0.1 · **Date:** 2026-06-09

Each requirement has a stable ID. Priority uses **MoSCoW**: M=Must, S=Should, C=Could, W=Won't (this release). "Rel" = target release.

---

## 1. Functional requirements

### 1.1 Transaction capture — manual (FR-CAP)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-CAP-01 | M | MVP | The user can create an **expense**, **income**, or **transfer** transaction. |
| FR-CAP-02 | M | MVP | A transaction has: date, type, payee/merchant, account, currency, total amount, optional note, optional tags. |
| FR-CAP-03 | M | MVP | A transaction can contain one or more **line items**, each with description, quantity, unit price, line amount, and category. |
| FR-CAP-04 | M | MVP | If no line items are entered, the transaction is treated as a single implicit line in one category. |
| FR-CAP-05 | M | MVP | Line item amounts must reconcile to the transaction total; the app shows the difference and warns if unbalanced. |
| FR-CAP-06 | S | MVP | The user can duplicate a transaction to speed up repetitive entry. |
| FR-CAP-07 | S | v0.3 | The user can define **recurring** transactions (period, next date) that auto-generate entries. |
| FR-CAP-08 | M | MVP | The user can edit and delete any transaction; deletes are soft (recoverable) until purged. |

### 1.2 Transaction capture — scanning (FR-SCAN)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-SCAN-01 | M | v0.2 | The user can import a document from an **image file** (PNG/JPG/TIFF/HEIC), **PDF**, or directly from a **connected scanner/webcam**. |
| FR-SCAN-02 | M | v0.2 | The app classifies the document type (receipt / invoice / bill / paycheck) and applies the matching parser. |
| FR-SCAN-03 | M | v0.2 | OCR runs **fully offline** on-device. |
| FR-SCAN-04 | M | v0.2 | The app extracts header fields: merchant, date, total, currency, tax. |
| FR-SCAN-05 | M | v0.2 | The app extracts **line items** (description, qty, unit price, amount) where present. |
| FR-SCAN-06 | M | v0.2 | A **review screen** shows the original document beside the extracted data; every field is editable before saving. |
| FR-SCAN-07 | M | v0.2 | Extracted line items get **auto-suggested categories**; the user can accept or change them. |
| FR-SCAN-08 | M | v0.2 | The original document file is stored (encrypted) and **attached** to the saved transaction. |
| FR-SCAN-09 | S | v0.2 | The app supports basic image **pre-processing** (deskew, crop, contrast/threshold) to improve OCR. |
| FR-SCAN-10 | C | v0.3 | The app learns per-merchant **document templates** to improve future extraction. |
| FR-SCAN-11 | M | v0.2 | Each extracted field shows a **confidence indicator**; low-confidence fields are highlighted for review. |

### 1.3 Categorization (FR-CAT)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-CAT-01 | M | MVP | The app ships with a default category set (Food, Groceries, Dining, Utilities, Housing, Transport, Health, Fun/Leisure, Shopping, Income, etc.). |
| FR-CAT-02 | M | MVP | The user can create, rename, recolor, assign icons to, and archive categories. |
| FR-CAT-03 | M | MVP | Categories support **subcategories** (one level of nesting minimum). |
| FR-CAT-04 | M | MVP | A single transaction's line items may belong to **different categories** (multi-category split). |
| FR-CAT-05 | S | v0.2 | **Auto-categorization rules**: match by merchant / keyword / regex → category, with priority ordering. |
| FR-CAT-06 | S | v0.2 | The app **remembers** a merchant's last/most-used category and suggests it. |
| FR-CAT-07 | C | v0.3 | Bulk re-categorization of filtered transactions. |
| FR-CAT-08 | S | MVP | A line item can carry **tags** (free-form labels) in addition to its category. |

### 1.4 Multi-currency (FR-CUR)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-CUR-01 | M | MVP | The user sets a **base/home currency** used for all aggregated reporting. |
| FR-CUR-02 | M | MVP | Each transaction stores its **original currency** and amount. |
| FR-CUR-03 | M | MVP | The app converts to base currency using the **exchange rate effective on the transaction date**. |
| FR-CUR-04 | M | MVP | Exchange rates can be entered manually and are stored historically (per date). |
| FR-CUR-05 | S | v0.3 | The app can **optionally fetch** rates online on demand (one-off; never required for normal use). |
| FR-CUR-06 | M | MVP | Money is stored and computed without floating-point error (decimal); rounding rules are explicit. |

### 1.5 Accounts (FR-ACC)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-ACC-01 | S | MVP | The user can define accounts (cash, bank, card) each with a currency and optional opening balance. |
| FR-ACC-02 | S | MVP | A transaction is assigned to an account; balances update accordingly. |
| FR-ACC-03 | S | MVP | **Transfers** move money between accounts without counting as expense or income. |

### 1.6 Analytics & visualization (FR-ANL)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-ANL-01 | M | MVP | **Dashboard**: current-month income, expense, net, balance, top categories, budget status. |
| FR-ANL-02 | M | MVP | **Spending by category** chart (pie/donut) with drill-down to subcategory and transactions. |
| FR-ANL-03 | M | MVP | **Spending over time** chart (line / stacked area) by period (day/week/month/year). |
| FR-ANL-04 | M | MVP | **Income vs expense** comparison (bar). |
| FR-ANL-05 | M | MVP | Global **filters**: date range, category, subcategory, account, currency, merchant, tag. |
| FR-ANL-06 | S | v0.3 | **Budget vs actual** view with progress and over/under indicators. |
| FR-ANL-07 | C | v0.3 | **Treemap** of category spend; **calendar heatmap** of daily spend; **waterfall** of monthly cash flow. |
| FR-ANL-08 | C | v0.3 | **Top merchants** analysis and **recurring/subscription** detection. |
| FR-ANL-09 | S | v0.3 | **Month-over-month** and **year-over-year** comparison views. |
| FR-ANL-10 | M | MVP | All charts reflect the active filters and base currency; clicking a chart segment drills into the underlying transactions. |

### 1.7 Budgets (FR-BUD)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-BUD-01 | S | v0.3 | The user can set a periodic (monthly) budget per category. |
| FR-BUD-02 | S | v0.3 | The app shows spend vs budget and alerts when nearing/over budget. |

### 1.8 Data management (FR-DAT)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-DAT-01 | M | MVP | All data persists in a local encrypted SQLite database. |
| FR-DAT-02 | M | MVP | **Backup**: export the full encrypted database/archive to a user-chosen file. |
| FR-DAT-03 | M | MVP | **Restore** from a backup file. |
| FR-DAT-04 | M | MVP | **CSV export** of transactions/line items (filtered or all). |
| FR-DAT-05 | S | MVP | **CSV import** with column mapping for transactions. |
| FR-DAT-06 | S | v0.3 | **PDF report export** of a chosen view/period. |
| FR-DAT-07 | M | MVP | Schema **migrations** run automatically and safely on version upgrade. |

### 1.9 Security & access (FR-SEC)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-SEC-01 | M | MVP | The database is encrypted at rest (SQLCipher / AES-256). |
| FR-SEC-02 | M | MVP | The app is unlocked with a master password; the key is derived via a strong KDF. |
| FR-SEC-03 | S | v0.3 | Optional **Windows Hello** unlock. |
| FR-SEC-04 | M | MVP | Attached documents are stored encrypted alongside the database. |
| FR-SEC-05 | S | v1.0 | Auto-lock after a configurable idle timeout. |

Full detail in [09-security-privacy.md](09-security-privacy.md).

## 2. Non-functional requirements (NFR)

| ID | Category | Requirement |
|----|----------|-------------|
| NFR-01 | Performance | Cold start < 2s; warm navigation < 200ms; any analytics view renders < 1s with 10,000 transactions. |
| NFR-02 | Scale | Handle ≥ 100,000 transactions and ≥ 5 GB of attachments without degradation. |
| NFR-03 | Offline | 100% of features (except optional rate fetch) work with no network. |
| NFR-04 | Privacy | No telemetry or user data leaves the device by default; any network call is explicit and opt-in. |
| NFR-05 | Reliability | No data loss on crash/power-off (transactional writes, WAL); automatic local snapshot before migrations. |
| NFR-06 | Usability | Primary tasks reachable in ≤ 2 clicks; keyboard-friendly entry; undo for destructive actions. |
| NFR-07 | Accessibility | Keyboard navigation, screen-reader labels, high-contrast theme, scalable fonts (target WCAG 2.1 AA where applicable). |
| NFR-08 | Localization | UI strings externalized; ship English + Czech; locale-aware number/date/currency formatting. |
| NFR-09 | Maintainability | Layered architecture, ≥ 70% unit-test coverage on core/domain logic, CI build. |
| NFR-10 | Portability | x64 Windows 10 (1809+) and 11; no admin rights required to run. |
| NFR-11 | Installability | MSIX installer with signed package and auto-update (v1.0); xcopy/unpackaged option for dev. |
| NFR-12 | Security | Data-at-rest AES-256; key never written to disk in plaintext; memory zeroed where practical. |
| NFR-13 | Recoverability | Backup/restore round-trips losslessly; restore validates integrity before overwriting. |

## 3. Traceability

Every functional requirement traces to at least one user story in [01-product-requirements.md](01-product-requirements.md) and is realized by entities in [04-data-model.md](04-data-model.md) and phases in [08-implementation-roadmap.md](08-implementation-roadmap.md). The roadmap's acceptance criteria reference these IDs.
