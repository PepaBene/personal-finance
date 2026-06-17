# Implementation Roadmap

**Version:** 0.1 · **Date:** 2026-06-09

A phased plan. Each phase ends with a runnable build and explicit acceptance criteria tracing to requirement IDs in [02](02-functional-requirements.md).

---

## Phase 0 — Foundation & scaffolding
**Goal:** a buildable, layered solution with encrypted storage and one end-to-end vertical slice.

- Create solution structure (Domain / Application / Infrastructure / App / tests) per [03 §3](03-architecture.md).
- Set up DI/hosting, Serilog logging, settings store.
- EF Core 10 + SQLite + **SQLCipher** wired; first migration; `PRAGMA foreign_keys`, WAL.
- App lock: master password → KDF → DB key (FR-SEC-01/02).
- CI (GitHub Actions, Windows): build + test.
- **Vertical slice:** create & list a basic Transaction (no line items yet) through all layers.

**Exit criteria:** app launches, unlocks with password, persists one encrypted transaction, reopens it. Unit tests green in CI.

## Phase 1 — MVP core (capture + categorize + core analytics)
**Goal:** fully usable manual expense tracker. Covers MVP rows in [02](02-functional-requirements.md).

Workstreams:
1. **Domain & data**: full schema from [04](04-data-model.md) — Transaction, LineItem, Category (hierarchical, seeded), Merchant, Account, Tag, Currency, ExchangeRate, Setting. Money value object + banker's rounding.
2. **Transaction capture** (FR-CAP-01..08): add/edit/delete, **line-item editor with multi-category split**, balance reconciliation, transfers.
3. **Categorization** (FR-CAT-01..04, 08): manage categories/subcategories, tags, assign per line item.
4. **Multi-currency** (FR-CUR-01..04, 06): base currency, per-transaction currency, manual historical rates, base-amount caching.
5. **Accounts** (FR-ACC): accounts, balances, transfers.
6. **Analytics MVP** (FR-ANL-01..05, 10): dashboard, spend-by-category, over-time, income-vs-expense, global filters, drill-down.
7. **Data** (FR-DAT-01..05, 07): encrypted DB, backup/restore, CSV import/export, auto migrations.
8. **UI shell**: NavigationView, all MVP screens from [06](06-ux-ui-spec.md), light/dark themes.

**Exit criteria:** user can manually run their whole finances — enter multi-category transactions in multiple currencies, categorize, see dashboard + 3 core charts with filters & drill-down, back up & restore, import/export CSV. NFR-01 perf met on 10k seeded transactions.

## Phase 2 — Scanning (offline OCR)
**Goal:** capture by document. Covers FR-SCAN-*, FR-CAT-05/06.

- `IOcrEngine` with **Windows.Media.Ocr** (primary) + **Tesseract** (optional); language config (CS/EN).
- Ingest: image files, scanner (WIA), webcam, **PDF** (PdfPig text path + rasterize-for-OCR path).
- Pre-processing with OpenCvSharp (deskew/threshold/crop).
- Document classifier + per-type parsers (receipt/invoice/paycheck), line-item layout reconstruction, reconciliation, confidence scoring.
- **Review screen** with image+overlay, editable fields, confidence highlighting (FR-SCAN-06/11).
- Encrypted attachment storage + OCR-text search (FR-SCAN-08).
- Auto-categorization rules engine + merchant memory (FR-CAT-05/06).
- Accuracy test harness with labeled fixture corpus ([05 §7](05-ocr-document-processing.md)); resolve ADR-003 (default engine).

**Exit criteria:** scan a printed receipt → reviewed → saved with itemized multi-category lines & attachment, meeting the accuracy targets in [05 §1](05-ocr-document-processing.md). Works fully offline.

## Phase 3 — Deeper analysis & budgets
**Goal:** richer insight. Covers FR-BUD, FR-ANL-06..09, FR-DAT-06, FR-SCAN-10.

- Budgets per category + actual-vs-budget + alerts.
- Advanced visualizations: treemap, calendar heatmap, waterfall, MoM/YoY, top merchants.
- Recurring/subscription detection.
- Recurring transaction templates (FR-CAP-07).
- PDF report export.
- Optional online exchange-rate fetch (FR-CUR-05) — explicit, opt-in.
- Per-merchant OCR templates (FR-SCAN-10).

**Exit criteria:** budgets tracked with alerts; all advanced charts live and drill-down; PDF report exports for a chosen period.

## Phase 4 — v1.0 polish & release
**Goal:** shippable product. Covers NFR-07/08/11, FR-SEC-03/05.

- MSIX packaging, code signing, auto-update.
- First-run onboarding wizard.
- Accessibility pass (keyboard, screen reader, high contrast) and localization (CS + EN).
- Windows Hello unlock; auto-lock timeout.
- Performance hardening to NFR-01/02 on 100k transactions; rollup cache.
- Crash reporting (local only), docs/help.

**Exit criteria:** signed installer, onboarding, AA-level accessibility on core flows, CS/EN localized, all NFRs met.

---

## Cross-phase: definition of done (every feature)
- Code in correct layer; interfaces in Application, impls in Infrastructure.
- Unit tests for domain/application logic; ≥ 70% coverage on core (NFR-09).
- Nullable refs on; analyzers clean; warnings-as-errors in core libs.
- Requirement IDs referenced in PR; docs updated if behavior changed.
- Manual smoke on the relevant screen.

## Sequencing rationale
- Encryption & layering are in Phase 0 because retrofitting them is costly.
- The **line-item/split model lands in MVP** (not deferred) because categorization, analytics, and later scanning all depend on it — it's the spine of the data model.
- Scanning (Phase 2) builds on a solid manual model, so OCR output maps onto proven entities and the review screen reuses the line-item editor.
- Heavy/advanced visualizations wait until real data and the aggregation layer exist (Phase 3).

## Tracking
Use the issue tracker with labels per phase and requirement IDs (e.g. `FR-CAP-03`). A milestone per phase; acceptance criteria above are the milestone exit checklists.
