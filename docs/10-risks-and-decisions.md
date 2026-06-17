# Risks & Decision Log (ADRs)

**Version:** 0.1 · **Date:** 2026-06-09

---

## Part A — Risk register

Likelihood (L) / Impact (I): Low / Med / High.

| ID | Risk | L | I | Mitigation |
|----|------|---|---|------------|
| R-01 | **Local OCR accuracy** on messy receipts is below user expectation. | High | High | Mandatory human review (FR-SCAN-06); strong preprocessing; dual engine (Windows OCR + Tesseract); confidence flags; graceful fallback to single-line draft; accuracy test harness to tune. Set expectations in onboarding. |
| R-02 | **WinUI 3 immaturity** (tooling/library gaps) slows UI work. | Low | Med | *Reduced (2026-06):* WinUI now on a Long-Term Servicing Channel (WASDK 2.0) and LiveCharts2 reached stable 2.0 with a WinUI package. Still: keep UI thin over framework-agnostic ViewModels; WPF fallback (ADR-001) reuses ~80% of code. |
| R-03 | **Line-item layout parsing** is brittle across vendors. | High | Med | Generic row/column reconstruction + per-merchant templates (FR-SCAN-10); always reconcile to total; never auto-save. |
| R-04 | **Multi-currency rounding / FX correctness** bugs cause wrong totals. | Med | High | `decimal` + Money value object; banker's rounding at boundaries only; historical rate per date; unit tests on conversion edge cases. |
| R-05 | **Encryption/key handling mistake** leaks data or locks user out. | Low | High | Proven SQLCipher; standard KDF; pre-migration snapshots; restore validates before overwrite; explicit "no password recovery" messaging. |
| R-06 | **Performance** degrades on large datasets (100k+ tx, big attachments). | Med | Med | SQL-side aggregation, indexes, UI virtualization, rollup cache, async I/O; perf tested against seeded data (NFR-01/02). |
| R-07 | **PDF variety** (scanned vs digital, multi-page) breaks ingest. | Med | Med | Detect text layer (PdfPig) vs rasterize (Docnet); per-page progress; fallback to manual. |
| R-08 | **Scope creep** (bank feeds, mobile, multi-user) delays v1. | Med | Med | Non-goals fixed in PRD; phased roadmap; data model leaves room without building now. |
| R-09 | **HEIC / image format** decoding issues on some Windows installs. | Low | Low | Rely on Windows codecs; convert on import; document supported formats. |
| R-10 | **Data loss** on crash or bad migration. | Low | High | WAL + transactions; automatic pre-migration snapshot; tested backup/restore round-trip (NFR-05/13). |
| R-11 | **Solo-project maintenance / bus factor.** | Med | Med | Clear layered architecture, tests, and this doc set; conventional stack (.NET/EF) for future maintainability. |
| R-12 | **Tesseract language-data / licensing** footprint. | Low | Low | Tesseract is Apache-2.0; bundle only needed `traineddata`; Windows.Media.Ocr as zero-dependency default. |

## Part B — Architecture Decision Records (ADRs)

### ADR-001 — UI framework: WinUI 3 (primary), WPF (fallback)
**Status:** Accepted (provisional, revisit end of Phase 1).
**Context:** Need a native Windows desktop UI with rich charts and a modern look; not a PWA.
**Decision:** Build on **WinUI 3 (Windows App SDK)** for Fluent/native feel and Microsoft's forward path. Keep all logic in framework-agnostic ViewModels/services so a switch to **WPF** is cheap if WinUI 3 tooling/library gaps bite.
**Consequences:** Modern UI, MSIX-friendly; some ecosystem immaturity risk (R-02), de-risked by cross-UI charting (LiveCharts2) and the thin-UI rule.
**Alternatives:** WPF (more mature, slightly dated look) — retained as fallback; Electron/Tauri (web stack) and Flutter — rejected per the chosen .NET-native direction.

### ADR-002 — Storage: encrypted SQLite via EF Core + SQLCipher
**Status:** Accepted.
**Context:** Local-only, private, relational data with reporting; must be encrypted at rest.
**Decision:** **SQLite + SQLCipher** for an encrypted single-file local DB; **EF Core 10** for modeling, migrations, LINQ analytics.
**Consequences:** Simple deployment (one file), strong at-rest encryption, easy backup. EF aggregation keeps analytics fast.
**Alternatives:** LiteDB (weaker querying), plaintext SQLite + app-level field encryption (worse, leaks structure), SQL Server/Postgres (overkill, not local-file-friendly).

### ADR-003 — OCR engine: Windows.Media.Ocr default, Tesseract optional
**Status:** Proposed (decide during Phase 2 via accuracy harness).
**Context:** Must be fully offline; balance accuracy, footprint, and zero-install.
**Decision (proposed):** Default to **Windows.Media.Ocr** (built-in, no dependency, offline) behind `IOcrEngine`; offer **Tesseract** as an optional higher-tunability engine. Choose the shipped default from measured accuracy on the fixture corpus ([05 §7](05-ocr-document-processing.md)).
**Consequences:** Zero-install baseline; swappable engines; decision is data-driven, not guessed.
**Alternatives:** Cloud OCR (rejected — violates privacy goal); PaddleOCR (heavier native deps).

### ADR-004 — Attachment storage: encrypted files vs DB BLOBs
**Status:** Proposed (decide early Phase 2).
**Context:** Original documents must be stored encrypted and linked to transactions.
**Options:** (a) BLOBs inside the encrypted DB — automatically encrypted, single-file backup, but DB grows large; (b) AES-GCM-encrypted files under `attachments/` with paths in DB — keeps DB lean, streams large files, slightly more code and a multi-part backup.
**Leaning:** (b) encrypted files for scalability (NFR-02), with the DB holding metadata + OCR text. Revisit if single-file backup simplicity is preferred.

### ADR-005 — Money representation: decimal + Money value object
**Status:** Accepted.
**Context:** Financial correctness; multi-currency.
**Decision:** Store/compute money as `decimal` (`DECIMAL(19,4)`), wrapped in a `Money(Amount, CurrencyCode)` value object; banker's rounding applied only at persistence/display; FX via historical per-date rates with cached base amounts.
**Consequences:** No float drift; currency-safe arithmetic; clear conversion semantics. ([04 §3](04-data-model.md))

### ADR-006 — Categorization at line-item granularity
**Status:** Accepted.
**Context:** Bills can contain items from multiple categories (core requirement FR-CAT-04).
**Decision:** Categorize **line items**, not whole transactions. A "split" is simply line items with different `CategoryId`s. Analytics aggregate at line level.
**Consequences:** Naturally supports multi-category bills, accurate category analytics, and OCR line-item mapping. Slightly more entry effort for simple expenses — mitigated by a single-category quick mode ([06 §2.4](06-ux-ui-spec.md)).

### ADR-007 — Offline-first, no telemetry
**Status:** Accepted.
**Context:** Privacy is a primary product value.
**Decision:** No runtime network dependency; no telemetry/crash phone-home; only explicit opt-in network actions (rate fetch, update check), never sending financial data.
**Consequences:** Verifiably private; works firewalled; sets constraints on features (e.g. rates can be manual). ([09](09-security-privacy.md))

### ADR-008 — Target the current LTS / latest stable stack
**Status:** Accepted (2026-06-09, supersedes the original ".NET 8 / WASDK 1.5" draft).
**Context:** The first draft targeted .NET 8; verified on 2026-06-09 that **.NET 8 and .NET 9 both reach end-of-support in November 2026**, while **.NET 10 (LTS, Nov 2025 → Nov 2028)** and **Windows App SDK 2.0** are current. LiveCharts2 also reached a **stable 2.0** with a WinUI view package.
**Decision:** Target **.NET 10 / C# 14**, **Windows App SDK 2.0 (WinUI 3)**, **EF Core 10**, **Visual Studio 2026**, **CommunityToolkit.Mvvm ≥ 8.4.2** (8.4.0 fails on .NET 10), **LiveChartsCore 2.0.4+**. Use **central package management** (`Directory.Packages.props`) and re-audit versions (`dotnet list package --outdated/--vulnerable`) at the start of every phase.
**Consequences:** Longest support runway; access to EF Core 10 query/JSON improvements and C# 14; avoids building on a runtime that EOLs within months. Pinned baseline in [03 §2.1](03-architecture.md).
**Design impact (UI/UX):** WinUI's move to a Long-Term Servicing Channel and the new stable charting library materially lower the risk behind ADR-001, strengthening WinUI 3 as the primary choice.

### ADR-009 — Finance-app UX & design system
**Status:** Accepted.
**Context:** The product must feel clean, modern, trustworthy, and easy to use, following established finance-app UX principles.
**Decision:** Adopt a documented **design system** (tokens, components, motion, accessibility) and a set of finance-specific UX principles — see [12-design-system-and-ux.md](12-design-system-and-ux.md). Build on WinUI 3 Fluent design with a custom token layer so the look is intentional, not default.
**Consequences:** Consistent, accessible, trustworthy UI; a single source of truth for spacing/color/type that ViewModels and charts share; clear bar for "done" on every screen.

## Part C — Open questions to resolve before/early in build
1. Confirm working **app name** (currently "Ledgerly") and base currency default.
2. ADR-003: final default OCR engine after accuracy measurement.
3. ADR-004: attachment storage approach.
4. Argon2id vs PBKDF2 for the KDF (library/footprint trade-off).
5. Distribution: MSIX via signed sideload vs Microsoft Store (affects signing/update).
