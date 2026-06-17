# Top-Level Implementation Plan — Personal Accounting App ("Ledgerly")

**Date:** 2026-06-09 · **Status:** Pre-implementation (greenfield) · **Owner:** solo developer + Claude Code
**Source docs:** [`docs/00`–`docs/12`](../../docs/00-README.md). This plan operationalizes the phased roadmap ([docs/08](../../docs/08-implementation-roadmap.md)) into an executable, task-level strategy with code localization against the planned solution structure ([docs/03 §3](../../docs/03-architecture.md)).

---

## 1. Executive Summary

Ledgerly is a **local-first, offline, encrypted Windows desktop app** for personal expense tracking, built on **.NET 10 / C# 14** with a **WinUI 3 (Windows App SDK 2.0)** front end. It lets a single user capture transactions manually or by **offline-OCR scanning** of receipts/invoices/paychecks, categorize spending at **line-item granularity** (so one bill can span many categories), work in **multiple currencies**, and analyze everything through rich, honest visualizations — with all data held in an **encrypted SQLite (SQLCipher)** database that never leaves the device.

The approach is a **layered, MVVM, dependency-injected architecture** (Domain → Application → Infrastructure → App) that keeps business logic UI-agnostic and testable, and de-risks the one open framework question (WinUI 3 vs WPF) by keeping the UI thin over framework-neutral ViewModels. Work proceeds in **five sequential phases** (0: Foundation → 1: MVP manual tracker → 2: Offline scanning → 3: Advanced analytics & budgets → 4: v1.0 polish & release), each ending in a runnable build with explicit, requirement-traced acceptance criteria.

Expected outcome: a shippable, signed MSIX desktop app where manual entry takes < 10s, scan-to-saved < 30s, any analytics view renders < 1s on 10k transactions, and zero user financial data egresses the device. The highest-risk areas — encryption/key handling, the money/FX engine, and the line-item OCR pipeline — are sequenced early (encryption, data model) or isolated behind interfaces with mandatory human-in-the-loop review (OCR).

---

## 2. Critical Challenges & Risks Identified

> This is a greenfield build, so "issues" are the hard problems and risks that must be designed for up front rather than bugs in existing code. These expand on the risk register in [docs/10](../../docs/10-risks-and-decisions.md) with implementation-level analysis.

### Challenge 1: Encryption & key management must be right from day one
**Severity:** Critical
**Location:** `Ledgerly.Infrastructure/Persistence` (DbContext factory, connection setup), `Ledgerly.Infrastructure/Security` (KDF, app lock).
**Impact:** Retrofitting at-rest encryption after a schema and data exist is costly and error-prone; a mistake either leaks financial data or permanently locks the user out (no recovery by design).
**Root Cause:** SQLCipher keying happens at connection open (`PRAGMA key`) and the key is derived from the master password via a KDF — this crosses persistence, security, and app-startup concerns, so it must be architected before any data is written.
**Addressed by:** Phase 0, Tasks 0.3–0.4 (encrypted DbContext + app-lock/KDF) before any real schema/data.

### Challenge 2: Money & multi-currency correctness
**Severity:** Critical
**Location:** `Ledgerly.Domain/ValueObjects/Money.cs`, `Ledgerly.Application/Currency/CurrencyService`, EF value converters in `Ledgerly.Infrastructure/Persistence`.
**Impact:** Floating-point or rounding errors in a finance app destroy trust and make line-item-vs-total reconciliation fail. Wrong FX conversion corrupts every aggregate (all analytics aggregate on base-currency amounts).
**Root Cause:** Money spans domain (arithmetic, rounding), persistence (decimal mapping, no float), and analytics (per-date historical FX, cached base amounts). Conversions depend on a date-keyed rate lookup with fallback rules.
**Addressed by:** Phase 1, Tasks 1.1 (Money value object + banker's rounding) and 1.5 (currency/FX engine) with dedicated edge-case unit tests.

### Challenge 3: Line-item-grain data model is the spine of everything
**Severity:** Critical
**Location:** `Ledgerly.Domain/Entities` (Transaction, LineItem, Category…), `Ledgerly.Infrastructure/Persistence` (configs, migrations).
**Impact:** Categorization, multi-category split bills, OCR output mapping, and category analytics all depend on categorizing **line items**, not transaction headers. Getting the grain wrong forces a painful re-model later.
**Root Cause:** The requirement "a bill can include items from multiple categories" (FR-CAT-04) means the unit of analysis is the line item; transactions are just reconciling headers. Analytics, scanning, and budgets all build on this.
**Addressed by:** Phase 1, Task 1.2 — full schema with line-item grain landed in the MVP (not deferred), per ADR-006.

### Challenge 4: Offline OCR accuracy is inherently limited
**Severity:** High
**Location:** `Ledgerly.Infrastructure/Ocr`, `Ledgerly.Infrastructure/DocumentParsing`.
**Impact:** Local OCR on messy receipts will misread amounts and miss line items; over-trusting it produces wrong financial records.
**Root Cause:** No cloud OCR (privacy decision); on-device engines (Windows.Media.Ocr / Tesseract) are bounded, and line-item layout reconstruction across vendors is brittle.
**Addressed by:** Phase 2 — the pipeline is **assistive, not autonomous**: mandatory review screen, confidence flags, reconciliation to total, graceful single-line fallback, and an accuracy test harness to tune and choose the default engine (ADR-003).

### Challenge 5: Analytics performance at scale
**Severity:** Medium
**Location:** `Ledgerly.Application/Analytics/AnalyticsService`, EF queries, optional rollup tables.
**Impact:** Loading rows into memory to chart them will miss the < 1s / 10k-tx and 100k-tx targets (NFR-01/02).
**Root Cause:** Aggregations must run in SQL (GROUP BY/sums) over indexed columns, with caching and an optional monthly rollup, not in C# after materialization.
**Addressed by:** Phase 1 analytics built SQL-first; Phase 3 adds rollup cache and heavier charts once real data volume exists.

### Challenge 6: WinUI 3 UI risk & design consistency
**Severity:** Low–Medium (reduced 2026-06)
**Location:** `Ledgerly.App` (Views, ViewModels, token dictionaries).
**Impact:** Tooling/library gaps could slow UI; inconsistent styling would undermine the "clean, modern, trustworthy" goal.
**Root Cause:** WinUI historically had ecosystem gaps; mitigated now that WinUI is on an LTSC (WASDK 2.0) and LiveCharts2 reached stable 2.0 with a WinUI package.
**Addressed by:** Thin UI over framework-neutral ViewModels (WPF fallback reuses ~80%), and a token-based design system ([docs/12](../../docs/12-design-system-and-ux.md)) so charts and UI share one source of truth.

---

## 3. Implementation Strategy

### Solution Approach
Build **bottom-up through the layers, vertically sliced per feature**. Phase 0 establishes the skeleton (solution, DI, logging, **encrypted** persistence, app lock) and proves one end-to-end slice. Phase 1 delivers a fully usable manual tracker (the data-model spine, capture with splits, multi-currency, core analytics, backup/restore, import/export). Phase 2 layers offline scanning onto the proven manual model, reusing the line-item editor for the review screen. Phase 3 deepens analytics and adds budgets/recurring. Phase 4 hardens and packages for release.

Two rules keep risk low: **(a) hard problems first** — encryption and the money/data model are foundational and land before dependent features; **(b) everything behind interfaces** — OCR engines, repositories, rate providers, and file storage are ports in `Application`, implemented in `Infrastructure`, so they're swappable and unit-testable without a UI.

### Key Technical Decisions
- **Layered + MVVM + DI** ([docs/03](../../docs/03-architecture.md)): Domain has zero framework deps; App composes Infrastructure only at the DI root. Enables ≥70% core test coverage (NFR-09).
- **.NET 10 / WinUI 3 (WASDK 2.0) / EF Core 10**, latest LTS, pinned via central package management (ADR-008, [docs/03 §2.1](../../docs/03-architecture.md)).
- **Encrypt first** (ADR-002): SQLCipher keyed at startup before any schema work.
- **Line-item grain** (ADR-006): categorization/analytics aggregate line items; a "split" is just lines with different categories.
- **Money as `decimal` + `Money` value object** (ADR-005) with banker's rounding only at boundaries; FX via per-date historical rates with cached base amounts.
- **OCR assistive, not autonomous** (ADR-003): mandatory review, confidence-scored, with fallback.
- **Token-driven UI** (ADR-009): one source of truth for color/space/type shared by XAML and charts.
- **SQL-first analytics**: aggregates computed in-DB, cached, with optional rollups.

### Dependencies and Prerequisites
- Tooling: **.NET 10 SDK**, **Visual Studio 2026** (or `dotnet` CLI 10), **Windows App SDK 2.0** workload, Git.
- NuGet baseline (central `Directory.Packages.props`, [docs/03 §2.1](../../docs/03-architecture.md)): EF Core 10, Microsoft.Data.Sqlite 10, `SQLitePCLRaw.bundle_e_sqlcipher`, CommunityToolkit.Mvvm ≥8.4.2, Microsoft.Extensions.* 10, LiveChartsCore.SkiaSharpView.WinUI ≥2.0.4, Serilog (+File), FluentValidation, PdfPig, Docnet.Core/PDFtoImage, OpenCvSharp4, Tesseract + tessdata (ces/eng), xUnit/FluentAssertions/NSubstitute.
- Test corpus: a small labeled set of CZ/EN receipts/invoices/payslips with ground-truth JSON for the OCR accuracy harness (Phase 2).
- Decisions to lock before the phase that needs them: app name & default base currency (Phase 1), default OCR engine (Phase 2, data-driven), attachment storage = files vs BLOBs (Phase 2, ADR-004), KDF Argon2id vs PBKDF2 (Phase 0/1), distribution channel (Phase 4).

---

## 4. Implementation Phases

### Phase 0: Foundation & Scaffolding
**Complexity:** Medium · **Type:** Critical (blocks everything)
**Objective:** A buildable, layered, dependency-injected solution with **encrypted** storage, app unlock, logging, and CI, proven by one end-to-end vertical slice.

#### Tasks

##### Task 0.1: Solution & project scaffolding
**Location:** `Ledgerly.sln`; `src/Ledgerly.Domain`, `src/Ledgerly.Application`, `src/Ledgerly.Infrastructure`, `src/Ledgerly.App` (WinUI 3); `tests/Ledgerly.Domain.Tests`, `tests/Ledgerly.Application.Tests`, `tests/Ledgerly.Infrastructure.Tests`.
**Reasoning:** The project-reference graph (App→Application→Domain; Infrastructure→Application/Domain; Domain→nothing) physically enforces the architecture so layering can't rot.
**Implementation Details:** Create the multi-project solution per [docs/03 §3](../../docs/03-architecture.md). Add `Directory.Packages.props` (central package management) and `Directory.Build.props` enabling nullable reference types, `LangVersion=14`, analyzers, and warnings-as-errors for the three core libraries (not the App, to avoid XAML-gen noise). Wire reference direction; add empty test projects.
**Code Localization:** new solution; root build props files.
**Considerations:** Keep `Domain` dependency-free (no EF, no WinUI). Verify `dotnet build` and `dotnet test` succeed empty.

##### Task 0.2: App host, DI, configuration, logging
**Location:** `Ledgerly.App/App.xaml.cs` (composition root), `Ledgerly.App/Bootstrap/ServiceRegistration.cs`, `Ledgerly.Infrastructure/DependencyInjection.cs`.
**Reasoning:** A single composition root with `Microsoft.Extensions.Hosting` gives one place to register services, config, and logging, and makes services swappable/testable.
**Implementation Details:** Configure the generic host; register `IServiceProvider` for ViewModel resolution; add Serilog with a **local rolling-file sink only** (no network sink — NFR-04). Define a settings abstraction (`ISettingsStore`) backed later by the DB + a small local JSON for non-sensitive prefs.
**Considerations:** No telemetry/phone-home. Logs go under `%LOCALAPPDATA%\Ledgerly\logs`.

##### Task 0.3: Encrypted persistence (SQLCipher) — ⚠️ see deep-thinking note
**Location:** `Ledgerly.Infrastructure/Persistence/LedgerlyDbContext.cs`, `.../DbContextFactory.cs`, `.../EncryptionKeyProvider.cs`.
**Reasoning:** Encryption must exist before any real data is written (Challenge 1). SQLCipher requires the key at connection open.
**Implementation Details:** Use `Microsoft.Data.Sqlite` with `SQLitePCLRaw.bundle_e_sqlcipher`. On connection open, set `PRAGMA key` from the in-memory master key, then `PRAGMA foreign_keys=ON` and `PRAGMA journal_mode=WAL`. The key comes from `IAppLock` (Task 0.4), never hard-coded, never persisted in plaintext. Provide a design-time factory for migrations (using a throwaway dev key).
**Considerations:** Verify the DB file is unreadable without the key (open it with a plain SQLite tool → should fail). Handle wrong-password (decrypt failure) gracefully. WAL + encryption interactions tested.

##### Task 0.4: App lock — master password → KDF → key
**Location:** `Ledgerly.Application/Security/IAppLock.cs`, `Ledgerly.Infrastructure/Security/AppLock.cs`, `Ledgerly.App/Views/LockView.xaml`(+VM).
**Reasoning:** Single gate that derives the DB key from the user's password and holds it only while unlocked (FR-SEC-01/02).
**Implementation Details:** Derive a 256-bit key via **Argon2id** (preferred) or PBKDF2-HMAC-SHA256 (high iteration) with a per-install random salt stored in local config (salt + KDF params are non-secret). First run = set password (creates DB + salt). Subsequent runs = unlock. Hold key in a pinned/`SecureString`-style buffer; clear on lock/exit (best-effort under .NET GC). Support `PRAGMA rekey` for password change.
**Considerations:** Communicate "no password recovery." Throttle unlock attempts. Decide Argon2id vs PBKDF2 here (open question).

##### Task 0.5: First migration + vertical slice
**Location:** `Ledgerly.Infrastructure/Persistence/Migrations`, `Ledgerly.Domain/Entities/Transaction.cs` (minimal), `Ledgerly.Application/Transactions/ITransactionService.cs`, `Ledgerly.App/Views/TransactionsView` (minimal list + add).
**Reasoning:** Prove the whole stack end-to-end before building breadth.
**Implementation Details:** A minimal `Transaction` (id, date, amount, currency, note), one EF migration (auto-applied on startup with a pre-migration snapshot), a service to add/list, and a bare UI to create and re-read one record through all layers, unlocked by password.
**Considerations:** Confirm data survives app restart and is encrypted on disk.

##### Task 0.6: CI pipeline
**Location:** `.github/workflows/ci.yml`.
**Reasoning:** Guard quality from commit one.
**Implementation Details:** Windows runner: restore → build → run unit tests → (optional) package. Fail on warnings in core libs.
**Considerations:** Cache NuGet; matrix not needed (Windows-only).

#### Success Criteria
- [ ] `dotnet build`/`test` green locally and in CI.
- [ ] App launches, sets/checks master password, and **cannot** be opened with a wrong password.
- [ ] One transaction persists, is encrypted at rest (unreadable without key), and reloads after restart.
- [ ] Pre-migration snapshot is written before migrations run.

```
⚠️ DEEP THINKING REQUIRED
Tasks 0.3–0.4 (encryption + key handling) are security-critical and architecturally foundational.
Claude Code should: verify the DB is truly unreadable without the key; confirm the key is never
written to disk in plaintext; test wrong-password and password-change (rekey) paths; and validate
WAL + foreign_keys pragmas apply on every connection.
```

---

### Phase 1: MVP Core — Manual Tracker
**Complexity:** High · **Type:** Critical
**Objective:** A fully usable manual expense tracker: full schema (line-item grain), capture with multi-category splits, multi-currency, accounts, core analytics, backup/restore, CSV import/export, and the themed UI shell. Covers all MVP-tagged requirements in [docs/02](../../docs/02-functional-requirements.md).

#### Tasks

##### Task 1.1: Money value object & rounding — ⚠️ deep thinking
**Location:** `Ledgerly.Domain/ValueObjects/Money.cs`, `.../Currency.cs`; EF converters in `Ledgerly.Infrastructure/Persistence/Conversions`.
**Reasoning:** Correct money is non-negotiable (Challenge 2). Centralizing it prevents float drift and ad-hoc rounding everywhere.
**Implementation Details:** `Money(decimal Amount, string CurrencyCode)` immutable value object; arithmetic guards against mixing currencies without a rate; banker's rounding (`MidpointRounding.ToEven`) to the currency's decimal digits applied only at persistence/display boundaries. EF maps `decimal(19,4)`; no doubles anywhere in the money path.
**Considerations:** Unit-test rounding edges, negative amounts, zero, and currency-mismatch exceptions.

##### Task 1.2: Full domain model & schema (line-item grain) — ⚠️ deep thinking
**Location:** `Ledgerly.Domain/Entities/*` (Transaction, LineItem, Category, Merchant, Account, Tag, LineItemTag, Currency, ExchangeRate, Setting), `Ledgerly.Infrastructure/Persistence/Configurations/*`, new migration.
**Reasoning:** This is the spine (Challenge 3); categorization, scanning, and analytics all depend on it.
**Implementation Details:** Implement every entity and relationship from [docs/04](../../docs/04-data-model.md): hierarchical `Category` (self-ref parent, seeded default set), `Transaction` header with cached `BaseAmount`/`ExchangeRate`, `LineItem` with `CategoryId` (the split mechanism), merchants, accounts, tags (M:N), currencies, historical exchange rates, settings. Add the indexes in [docs/04 §5](../../docs/04-data-model.md). Soft-delete on Transaction. Seed default categories on first run.
**Considerations:** Enforce the invariant Σ(line amounts) == total within rounding tolerance (domain rule, surfaced in UI later). Cascade rules; FK enforcement. Get the grain right now — re-modeling later is expensive.

##### Task 1.3: Transaction capture service & line-item logic
**Location:** `Ledgerly.Application/Transactions/TransactionService.cs`, validators in `.../Transactions/Validation`.
**Reasoning:** Core use-cases: create/edit/delete (soft), reconcile lines to total, transfers.
**Implementation Details:** CRUD with FluentValidation; reconciliation computes Σlines vs total and flags imbalance (FR-CAP-05); transfers create paired account effects without counting as income/expense; duplicate-transaction helper. On save, call CurrencyService (1.5) to compute/cache base amount.
**Considerations:** Edit must re-reconcile and re-convert. Soft-delete + undo support.

##### Task 1.4: Categories, rules scaffolding, tags
**Location:** `Ledgerly.Application/Categories/CategoryService.cs`, `Ledgerly.Domain/Entities/CategorizationRule.cs` (entity now, engine in Phase 2).
**Reasoning:** Manage the category tree and tags used everywhere.
**Implementation Details:** CRUD for categories/subcategories (create/rename/recolor/icon/archive/reorder/re-parent), tag management, and the merchant→default-category field. Define the `CategorizationRule` entity now; defer the matching engine to Phase 2.
**Considerations:** Archiving must preserve history (don't hard-delete used categories).

##### Task 1.5: Currency & FX engine — ⚠️ deep thinking
**Location:** `Ledgerly.Application/Currency/CurrencyService.cs`, `Ledgerly.Domain/Entities/ExchangeRate.cs`.
**Reasoning:** All analytics aggregate on base currency (Challenge 2).
**Implementation Details:** Base-currency setting; per-transaction original currency; conversion uses the rate effective on the transaction date, falling back to the most recent rate on/before that date, else prompts. Manual rate entry stored historically. Changing base currency triggers a background recompute of all cached `BaseAmount`s. (Optional online fetch deferred to Phase 3.)
**Considerations:** Heavy unit tests: missing-rate fallback, same-currency no-op, base-currency change recompute, rounding after conversion.

##### Task 1.6: Accounts & balances
**Location:** `Ledgerly.Application/Accounts/AccountService.cs`.
**Reasoning:** FR-ACC: accounts, balances, transfers.
**Implementation Details:** CRUD for cash/bank/card accounts with opening balance; current balance = opening + signed sums; transfers move between accounts.
**Considerations:** Optionally cache balances; ensure transfers don't pollute spend analytics.

##### Task 1.7: Analytics service (SQL-first) & MVP charts
**Location:** `Ledgerly.Application/Analytics/AnalyticsService.cs`; `Ledgerly.App/Views/DashboardView`, `AnalyticsView`, chart controls.
**Reasoning:** Deliver dashboard + spend-by-category + over-time + income-vs-expense with global filters and drill-down (FR-ANL MVP). Centralize metrics so all screens reconcile (Challenge 5, [docs/11](../../docs/11-analysis-and-visualization-deep-dive.md)).
**Implementation Details:** Implement metrics from [docs/11 §2](../../docs/11-analysis-and-visualization-deep-dive.md) as in-SQL aggregates (GroupBy/sums) over indexed columns, aggregating line items on cached base share. Build the global filter context object that drives every view. Render with LiveCharts2; clicking a segment drills to the filtered transaction list.
**Considerations:** Debounce filter changes; cancel superseded queries; verify < 1s on 10k seeded rows.

##### Task 1.8: Data management — backup/restore, CSV import/export, migrations
**Location:** `Ledgerly.Infrastructure/IO/BackupService.cs`, `ImportExportService.cs`.
**Reasoning:** FR-DAT: protect and move data.
**Implementation Details:** Encrypted backup archive (DB + later attachments) to a user-chosen path; restore validates integrity + that the password decrypts before overwriting (snapshot current first). CSV export of filtered transactions/lines; CSV import with column mapping. Auto-migrations with pre-migration snapshot.
**Considerations:** Round-trip backup/restore losslessly (NFR-13). Import validation for bad rows.

##### Task 1.9: UI shell & MVP screens + design tokens
**Location:** `Ledgerly.App/Views/*`, `Ledgerly.App/Themes/Tokens.xaml` (+ light/dark dictionaries), shared components (`MoneyText`, `CategoryPicker`, `AmountInput`, `LineItemEditor`, `KpiCard`, `FilterBar`).
**Reasoning:** Realize the design system ([docs/12](../../docs/12-design-system-and-ux.md)) so the app is clean/modern/consistent from the start.
**Implementation Details:** NavigationView shell; implement MVP screens from [docs/06](../../docs/06-ux-ui-spec.md). Build the **design-token dictionaries** first and the reusable components (esp. `MoneyText` and `LineItemEditor` with the live balance indicator); no view hard-codes color/size/font. Charts styled from the same tokens. Light/dark themes.
**Considerations:** Keep ViewModels framework-neutral (WPF fallback). Per-screen accessibility + UX quality bar ([docs/12 §8–9](../../docs/12-design-system-and-ux.md)).

#### Success Criteria
- [ ] User can enter, edit, delete, and split a transaction across multiple categories in multiple currencies; lines reconcile to total.
- [ ] Base-currency conversion correct for past-dated transactions; changing base currency recomputes aggregates.
- [ ] Dashboard + 3 core charts honor global filters and drill down to transactions.
- [ ] Backup→restore round-trips losslessly; CSV import/export works.
- [ ] Analytics render < 1s on 10k seeded transactions (NFR-01).
- [ ] All MVP-tagged FRs in [docs/02](../../docs/02-functional-requirements.md) satisfied; ≥70% core test coverage.

```
⚠️ DEEP THINKING REQUIRED
Tasks 1.1, 1.2, 1.5 (money, schema grain, FX) are the correctness + architecture core.
Claude Code should think through rounding/currency edge cases, the line-item invariant, and
the historical-rate fallback before coding, and back each with unit tests.
```

---

### Phase 2: Offline Scanning
**Complexity:** High · **Type:** Critical (new subsystem) — see [docs/05](../../docs/05-ocr-document-processing.md)
**Objective:** Capture-by-document: ingest image/PDF/scanner → offline OCR → classify → parse header + line items → suggest categories → review → save with encrypted attachment. Covers FR-SCAN-*, FR-CAT-05/06.

#### Tasks

##### Task 2.1: OCR engine abstraction + Windows.Media.Ocr + Tesseract
**Location:** `Ledgerly.Application/Ocr/IOcrEngine.cs`, `Ledgerly.Infrastructure/Ocr/WindowsMediaOcrEngine.cs`, `TesseractOcrEngine.cs`.
**Reasoning:** Swappable, testable OCR; choose default via measured accuracy (ADR-003).
**Implementation Details:** `IOcrEngine.RecognizeAsync` returns words with bounding boxes + confidence. Implement the built-in Windows engine (offline, zero-install) and Tesseract (ces/eng tessdata). Language configurable.
**Considerations:** Async + cancelable. Normalize both engines to one `OcrResult` shape.

##### Task 2.2: Ingest (image/PDF/scanner) + preprocessing
**Location:** `Ledgerly.Infrastructure/DocumentParsing/Ingest`, `.../Preprocess` (OpenCvSharp), PDF via PdfPig + Docnet.
**Reasoning:** Feed clean input to OCR; handle the PDF text-layer vs scanned split.
**Implementation Details:** Detect PDF text layer → extract directly with PdfPig (skip OCR); else rasterize pages (Docnet/PDFtoImage) → OCR. Image preprocessing: grayscale, denoise, adaptive threshold, deskew, perspective crop, upscale. Optional scanner (WIA) / webcam (MediaCapture) acquisition.
**Considerations:** Multi-page PDFs processed per page with progress.

##### Task 2.3: Document classifier + per-type parsers (header + line items) — ⚠️ deep thinking
**Location:** `Ledgerly.Infrastructure/DocumentParsing/Classifier.cs`, `Parsers/{ReceiptParser,InvoiceParser,PaycheckParser}.cs`, `IDocumentParser`.
**Reasoning:** The hardest accuracy problem (Challenge 4); line-item layout reconstruction is brittle.
**Implementation Details:** Keyword classifier picks a parser. Header fields via labeled-keyword + multilingual regex (merchant, date, total, currency, tax). Line items via layout reconstruction: group OCR words into rows by Y, detect the price column, take left-of-price as description. Money regex tolerant of `1 234,56`/`1,234.56`. Reconcile Σlines vs total; attach confidences. Output a non-persisted `DocumentDraft`.
**Considerations:** Never fabricate to force reconciliation. Fall back to a single-line draft (total+date+merchant) on low confidence. Paychecks → Income.

##### Task 2.4: Category suggestion + rules engine + merchant memory
**Location:** `Ledgerly.Application/Categorization/CategorizationService.cs`.
**Reasoning:** FR-CAT-05/06 — speed up categorization of scanned lines.
**Implementation Details:** Suggest per line via: CategorizationRule matches (priority order) → merchant default → keyword→category dictionary → Uncategorized. Persist user corrections back to merchant memory/rules.
**Considerations:** First-match-wins configurable; reuse in manual entry too.

##### Task 2.5: Scan review screen
**Location:** `Ledgerly.App/Views/ScanReviewView.xaml`(+VM), `ConfidenceField` control.
**Reasoning:** Mandatory human-in-the-loop (Challenge 4); the trust surface.
**Implementation Details:** Split view: original image with OCR box overlays | editable form bound to `DocumentDraft`. Confidence-colored fields (green/amber/red), low-confidence focused first. Reconciliation status visible. **Reuse the Phase 1 `LineItemEditor`.** Nothing saves until confirmed.
**Considerations:** Click a field → highlight its source region. Doc-type override.

##### Task 2.6: Encrypted attachment storage + OCR-text search
**Location:** `Ledgerly.Application/Documents/IFileStore.cs`, `Ledgerly.Infrastructure/IO/EncryptedFileStore.cs`, `Attachment` entity wiring, migration.
**Reasoning:** FR-SCAN-08 — store originals encrypted, searchable by OCR text.
**Implementation Details:** Resolve ADR-004 (encrypted files vs DB BLOBs); leaning AES-GCM-encrypted files under `attachments/` with metadata + `OcrText` in DB. SHA-256 for dedupe/integrity. Add OCR text to global search.
**Considerations:** Backup must include attachments. Stream large files.

##### Task 2.7: OCR accuracy test harness
**Location:** `tests/Ledgerly.Infrastructure.Tests/Ocr` + fixture corpus.
**Reasoning:** Make the engine-default decision data-driven (ADR-003) and prevent parser regressions.
**Implementation Details:** Labeled CZ/EN corpus with ground-truth JSON; measure header field accuracy + line-item precision/recall per engine. Unit-test parsers against fixed `OcrResult` fixtures (no image needed).
**Considerations:** Track metrics over time; pick shipped default from results.

#### Success Criteria
- [ ] Scan a printed receipt → review → save with itemized multi-category lines + encrypted attachment, fully offline.
- [ ] Header (total+date) accuracy ≥ 90%, line-item recall ≥ 70% on the corpus ([docs/05 §1](../../docs/05-ocr-document-processing.md)).
- [ ] Low-confidence fields flagged; single-line fallback works on poor scans.
- [ ] PDF (both text-layer and scanned) and at least one device path (scanner or webcam) supported.

```
⚠️ DEEP THINKING REQUIRED
Task 2.3 (parsers/line-item reconstruction) is the accuracy crux. Claude Code should reason about
layout heuristics and reconciliation, validate against fixtures, and never auto-save unreviewed data.
```

---

### Phase 3: Advanced Analytics, Budgets & Recurring
**Complexity:** Medium · **Type:** Parallel (independent feature areas)
**Objective:** Deepen insight. Covers FR-BUD, FR-ANL-06..09, FR-DAT-06, FR-SCAN-10, FR-CAP-07, FR-CUR-05.

#### Tasks
- **Task 3.1 — Budgets:** `BudgetService`, monthly per-category budgets, actual-vs-budget, calm alerts (FR-BUD). Bullet/progress components ([docs/12](../../docs/12-design-system-and-ux.md)).
- **Task 3.2 — Advanced visualizations:** treemap, calendar heatmap, cash-flow waterfall, MoM/YoY, top merchants ([docs/11 §4–8](../../docs/11-analysis-and-visualization-deep-dive.md)). Some need custom SkiaSharp series or ScottPlot — decide per chart.
- **Task 3.3 — Recurring/subscription detection:** heuristic grouping by merchant+amount+interval; recurring timeline + committed-monthly-spend KPI.
- **Task 3.4 — Recurring transaction templates:** auto-generate drafts on/after next date (FR-CAP-07).
- **Task 3.5 — PDF report export:** formatted local report (KPIs + breakdown + trend + top items) for a period (FR-DAT-06).
- **Task 3.6 — Optional online FX fetch:** explicit, opt-in, never required (FR-CUR-05).
- **Task 3.7 — Performance: monthly rollup cache** for instant dashboards on 100k+ tx (NFR-02); invalidate on data change.
- **Task 3.8 — Per-merchant OCR templates** to boost future extraction (FR-SCAN-10).

#### Success Criteria
- [ ] Budgets tracked with alerts; all advanced charts live and drill down.
- [ ] Recurring charges detected and surfaced; PDF report exports.
- [ ] Dashboards remain < 1s on 100k seeded transactions (rollup cache).
- [ ] Optional FX fetch is opt-in and offline-safe when disabled.

---

### Phase 4: v1.0 Polish & Release
**Complexity:** Medium · **Type:** Critical (release gate)
**Objective:** Ship. Covers NFR-07/08/11, FR-SEC-03/05.

#### Tasks
- **Task 4.1 — MSIX packaging, code signing, auto-update**; decide distribution (signed sideload vs Store).
- **Task 4.2 — First-run onboarding wizard** (base currency, password, categories, optional sample data).
- **Task 4.3 — Accessibility pass** to WCAG 2.1 AA on core flows; the [docs/12 §8](../../docs/12-design-system-and-ux.md) checklist per screen.
- **Task 4.4 — Localization** CS + EN; locale-aware formatting (NFR-08).
- **Task 4.5 — Windows Hello unlock + auto-lock timeout** (FR-SEC-03/05).
- **Task 4.6 — Performance hardening** to NFR-01/02; final profiling.
- **Task 4.7 — Local crash logging + help/docs.**

#### Success Criteria
- [ ] Signed installer with auto-update; onboarding works on a clean machine.
- [ ] AA accessibility verified on core flows; CS+EN localized; reduce-motion/high-contrast honored.
- [ ] All NFRs met; app verified fully functional offline/firewalled (zero financial-data egress).

---

### Phase Execution Order

```
Phase 0 (Foundation)  ──►  Phase 1 (MVP manual tracker)  ──►  Phase 2 (Scanning)  ──►  Phase 4 (Release)
                                        │                                              ▲
                                        └──────────►  Phase 3 (Advanced analytics) ────┘
```

- **0 → 1 → 2** are strictly sequential (each depends on the prior).
- **Phase 3** can begin once Phase 1's analytics/data exist and largely runs **in parallel** with/after Phase 2 (its sub-tasks 3.1–3.8 are mostly independent of each other).
- **Phase 4** is the final gate; some items (accessibility, localization) should be applied continuously but are formally verified here.

---

## 5. Success Metrics

### Validation Checklist
- [ ] All six challenges in Section 2 are designed for (encryption-first, money/FX engine, line-item grain, assistive OCR, SQL-first analytics, token-driven thin UI).
- [ ] Every phase's success criteria met, each tracing to requirement IDs in [docs/02](../../docs/02-functional-requirements.md).
- [ ] ≥70% unit-test coverage on Domain/Application (NFR-09); OCR accuracy harness green.
- [ ] Docs updated when behavior changes; ADR open questions (003/004, KDF, distribution) resolved at their phase.
- [ ] App works fully offline/firewalled; no telemetry; data encrypted at rest.

### Performance Targets
- Manual entry median < 10s; scan-to-saved median < 30s (incl. review).
- Cold start < 2s; warm navigation < 200ms; analytics views < 1s on 10k tx, dashboards < 1s on 100k tx (with rollup).
- OCR: header total+date ≥ 90%, line-item recall ≥ 70% on the test corpus.
- Zero network egress of user financial data (verifiable).

### Definition of Done (every feature)
Correct layer; interfaces in Application, impls in Infrastructure; unit tests; nullable + analyzers clean; requirement IDs referenced; design tokens/components only (no bespoke styling); verified light/dark + CS/EN + 150% scale; manual smoke on the screen.
