# Functional & Non-Functional Requirements

**Version:** 0.2 · **Date:** 2026-06-18

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
| FR-CAP-08 | M | MVP | The user can edit and delete any transaction; deletes are soft (recoverable) until purged, and soft-delete tombstones propagate through sync. |

### 1.2 Transaction capture — scanning (FR-SCAN)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-SCAN-01 | M | v0.2 | The user can import a document from an **image file** (PNG/JPG/TIFF/HEIC), **PDF**, or directly from a device **camera/webcam** (phone camera, document scanner, or desktop webcam). |
| FR-SCAN-02 | M | v0.2 | The app classifies the document type (receipt / invoice / bill / paycheck) and applies the matching parser. |
| FR-SCAN-03 | M | v0.2 | OCR runs **on-device** using a platform-adaptive engine (Android ML Kit, Apple Vision on iOS/macOS, Tesseract on Windows/Linux, Tesseract.js on web). An **opt-in cloud OCR fallback** may be used for hard documents; on-device remains the default for privacy and offline use. |
| FR-SCAN-04 | M | v0.2 | The app extracts header fields: merchant, date, total, currency, tax. |
| FR-SCAN-05 | M | v0.2 | The app extracts **line items** (description, qty, unit price, amount) where present. |
| FR-SCAN-06 | M | v0.2 | A **review screen** (adaptive split layout) shows the original document beside the extracted data; every field is editable before saving. |
| FR-SCAN-07 | M | v0.2 | Extracted line items get **auto-suggested categories**; the user can accept or change them. |
| FR-SCAN-08 | M | v0.2 | The original document file is stored **client-side encrypted** and **attached** to the saved transaction; the attachment syncs to cloud storage. |
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
| FR-DAT-01 | M | MVP | All data persists in a **local encrypted SQLite database (Drift)** on every device; native at-rest encryption via SQLCipher, web via Drift WASM + OPFS with a non-extractable WebCrypto key. |
| FR-DAT-02 | M | MVP | **Backup**: export the full encrypted database/archive to a user-chosen file. |
| FR-DAT-03 | M | MVP | **Restore** from a backup file. |
| FR-DAT-04 | M | MVP | **CSV export** of transactions/line items (filtered or all). |
| FR-DAT-05 | S | MVP | **CSV import** with column mapping for transactions. |
| FR-DAT-06 | S | v0.3 | **PDF report export** of a chosen view/period. |
| FR-DAT-07 | M | MVP | Schema **migrations** run automatically and safely on version upgrade, on both the local Drift schema and the cloud Postgres schema. |

### 1.9 Security & access (FR-SEC)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-SEC-01 | M | MVP | The local database is encrypted at rest (SQLCipher / AES-256 on native; non-extractable WebCrypto key on web). |
| FR-SEC-02 | M | MVP | The app is unlocked with a master password/passphrase; the encryption key is derived via a strong KDF (Argon2id). |
| FR-SEC-03 | S | v0.3 | Optional **biometric / local unlock** via `local_auth` (Face ID / Touch ID / Android biometrics / Windows Hello / macOS); web falls back to passphrase. |
| FR-SEC-04 | M | v0.2 | Attached documents are stored **client-side encrypted** locally and in cloud storage. |
| FR-SEC-05 | S | v1.0 | Auto-lock after a configurable idle timeout. |
| FR-SEC-06 | M | MVP | Cloud data is isolated per user via **Row-Level Security** (tenant isolation keyed to the authenticated user); data is encrypted in transit (TLS) and at rest in the cloud, with **client-side AES-256-GCM** for attachments and sensitive payloads. |

Full detail in [09-security-privacy.md](09-security-privacy.md).

### 1.10 Sync & multi-device (FR-SYNC)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-SYNC-01 | M | MVP | The app is **offline-first**: all features work without a connection against the local encrypted database; sync is never a prerequisite for core use. |
| FR-SYNC-02 | M | MVP | When online, local changes **sync to the cloud backend** (Supabase via PowerSync) and remote changes stream down so all of the user's devices **converge** to the same state. |
| FR-SYNC-03 | M | MVP | Every synced row carries sync metadata: `id` (UUID), `userId` (owner), `updatedAt` (UTC), `deleted` (soft-delete tombstone), and a per-row version/clock. |
| FR-SYNC-04 | M | MVP | **Conflict resolution** is deterministic: per-row **last-write-wins** on `updatedAt`, with child rows (e.g. line items) keyed to their parent so a transaction and its items stay consistent. |
| FR-SYNC-05 | M | MVP | Changes made on one online device are reflected on the user's other online devices within **a few seconds** (target < 5s median); offline edits converge within seconds of reconnecting. |
| FR-SYNC-06 | M | MVP | Sync is **encrypted in transit (TLS)**; attachments and sensitive payloads are **client-side encrypted** before upload (the server stores only ciphertext for those). |
| FR-SYNC-07 | M | MVP | Sync is **resilient**: it resumes after interruption, retries with backoff, and never loses or duplicates committed local changes (idempotent, tombstone-aware). |
| FR-SYNC-08 | S | MVP | The app exposes **sync status** (online/offline, syncing, last-synced time, pending changes) to the user. |
| FR-SYNC-09 | C | v0.3 | The user can trigger a **manual sync** / force-refresh. |

### 1.11 Account & authentication (FR-AUTH)

| ID | Priority | Rel | Requirement |
|----|----------|-----|-------------|
| FR-AUTH-01 | M | MVP | The user can **sign up** for an account with email + password; OAuth (Apple / Google) and magic-link sign-in are supported where available. |
| FR-AUTH-02 | M | MVP | The user can **sign in** and **sign out**; sessions use JWT + refresh tokens stored in platform secure storage. |
| FR-AUTH-03 | M | MVP | A user's data is bound to their authenticated identity and isolated from other users (enforced by Row-Level Security; see FR-SEC-06). |
| FR-AUTH-04 | S | v1.0 | The user can **reset their password** and (optionally) enable **MFA**. |
| FR-AUTH-05 | M | v1.0 | The user can **export all of their data** (transactions, line items, attachments, settings) in a portable format. |
| FR-AUTH-06 | M | v1.0 | The user can **delete their account**, which erases their cloud data (right to erasure); local data is also wiped on the signed-out device. |
| FR-AUTH-07 | S | v1.0 | Account recovery preserves access to client-side-encrypted data via a **recovery phrase** captured at setup (loss of both password and recovery phrase means encrypted data cannot be recovered — stated plainly to the user). |

Full detail in [09-security-privacy.md](09-security-privacy.md).

## 2. Non-functional requirements (NFR)

| ID | Category | Requirement |
|----|----------|-------------|
| NFR-01 | Performance | Cold start < 2s; warm navigation < 200ms; any analytics view renders < 1s with 10,000 transactions (per platform's native baseline). |
| NFR-02 | Scale | Handle ≥ 100,000 transactions and ≥ 5 GB of attachments per account without degradation, locally and through sync. |
| NFR-03 | Offline | **Offline-first**: 100% of core features (except optional rate fetch and cloud OCR fallback) work with no network; queued changes sync automatically on reconnect. |
| NFR-04 | Privacy | No telemetry or crash reporting by default; any such reporting is **opt-in**. User data is hosted only to enable sync, under tenant isolation, with documented data residency (prefer EU). |
| NFR-05 | Reliability | No data loss on crash/power-off (transactional writes, WAL); automatic local snapshot before migrations; sync never loses or duplicates committed changes. |
| NFR-06 | Usability | Primary tasks reachable in ≤ 2 taps/clicks; touch-friendly on mobile and keyboard-friendly on desktop/web; undo for destructive actions. |
| NFR-07 | Accessibility | Screen-reader labels (TalkBack/VoiceOver/Narrator), keyboard navigation on desktop/web, high-contrast theme, scalable fonts/text (target WCAG 2.1 AA where applicable). |
| NFR-08 | Localization | UI strings externalized (ARB/intl); ship English + Czech; locale-aware number/date/currency formatting. |
| NFR-09 | Maintainability | Layered, feature-first architecture; ≥ 70% unit-test coverage on core/domain logic; multi-platform CI build. |
| NFR-10 | Portability | Single Flutter/Dart codebase runs on **iOS, Android, Web (PWA), Windows, and macOS** (Linux best-effort); no admin rights required to run. |
| NFR-11 | Installability | Per-platform packaging and distribution: Android AAB (Google Play), iOS (App Store/TestFlight), macOS (notarized .dmg/.pkg + Mac App Store), Windows (MSIX / Inno Setup, optional Microsoft Store), Web (PWA with service worker on static hosting). |
| NFR-12 | Security | Data-at-rest AES-256 on device and in the cloud; TLS in transit; tenant isolation via RLS; client-side AES-256-GCM for attachments and sensitive payloads; keys derived via Argon2id and never written to disk in plaintext; memory zeroed where practical. |
| NFR-13 | Recoverability | Backup/restore round-trips losslessly; restore validates integrity before overwriting; a fresh device can fully rehydrate its local database from the cloud after sign-in. |
| NFR-14 | Sync | When online, changes **converge across the user's devices within seconds** (target < 5s median); sync is resilient to interruption, idempotent, tombstone-aware, and resumes with backoff. |

## 3. Traceability

Every functional requirement traces to at least one user story in [01-product-requirements.md](01-product-requirements.md) and is realized by entities in [04-data-model.md](04-data-model.md) and phases in [08-implementation-roadmap.md](08-implementation-roadmap.md); concrete build details live in [13-technical-implementation-plan.md](13-technical-implementation-plan.md). The new FR-SYNC and FR-AUTH groups trace to user stories US-21..US-25; the roadmap's acceptance criteria reference these IDs.
