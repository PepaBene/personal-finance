# Implementation Roadmap

**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform

A phased plan for the cross-platform Flutter re-platform of Ledgerly. Each phase ends with a runnable build on every target platform and explicit acceptance criteria tracing to requirement IDs in [02](02-functional-requirements.md). The product is now **offline-first and cloud-backed with encrypted multi-device sync** (see [01](01-product-requirements.md), [03](03-architecture.md), [09](09-security-privacy.md)), so sync and encryption are foundational rather than late additions.

---

## Phase 0 — Foundation & scaffolding
**Goal:** a buildable, layered, multi-platform Flutter app with encrypted local storage, a wired cloud backend, and one end-to-end vertical slice that **syncs across two devices**.

- Create the Flutter workspace (optionally a **melos** monorepo) with the layered, feature-first structure (Domain / Application / Data / Features) per [03 §3](03-architecture.md); `app/` plus optional shared `packages/`.
- **Dart 3.x / Flutter (stable channel)**; targets bootstrapped for iOS, Android, Web (PWA), Windows, macOS (Linux best-effort/dev).
- Wire **Riverpod 2.x** (with `riverpod_generator`) as the DI/state composition root; **go_router** for URL-based navigation, deep links and route guards.
- **Drift** over SQLite as the local DB: first tables + migration; native at-rest encryption via `sqlite3` + `sqlcipher_flutter_libs`; web via Drift **WASM + OPFS**; `PRAGMA foreign_keys`, WAL.
- Create the **Supabase** project (Postgres, Auth, Storage, RLS); mirror the first synced table in Postgres with **Row-Level Security** keyed to `auth.uid()`.
- **Supabase Auth** (email/password) sign-up/sign-in; JWT + refresh tokens persisted in `flutter_secure_storage`.
- **PowerSync** wired between Drift (SQLite) and Supabase (Postgres); sync rules stream the signed-in user's rows to the device (FR-SYNC-01/02).
- App lock skeleton: passphrase → **Argon2id** KDF → local DB key (FR-SEC-01/02).
- **Multi-platform CI** (GitHub Actions matrix): build + `dart analyze` + test for at least Android, Web, and one desktop target.
- **Vertical slice:** create & list a basic Transaction (no line items yet) through all layers, persisted to the encrypted local DB and **converging across two signed-in devices** via PowerSync.

**Exit criteria:** app launches on all primary platforms; a user can sign up, create one encrypted transaction offline, and see it appear on a second device once online; offline edits reconcile on reconnect. `dart analyze` clean and unit tests green in CI. (FR-SYNC-01/02, FR-SEC-01/02)

## Phase 1 — MVP core (capture + categorize + core analytics, syncing everywhere)
**Goal:** a fully usable manual expense tracker that is offline-first and sync-correct on every platform. Covers MVP rows in [02](02-functional-requirements.md).

Workstreams:
1. **Domain & data**: full schema from [04](04-data-model.md) — Transaction, LineItem, Category (hierarchical, seeded), Merchant, Account, Tag, Currency, ExchangeRate, Setting — as **Drift tables** with reactive `Stream` queries. Each synced table carries `id` (UUID), `userId`, `updatedAt` (UTC), `deleted` (tombstone) and a row version/clock (FR-SYNC-03). Money value object (`decimal`) + banker's rounding at boundaries.
2. **Transaction capture** (FR-CAP-01..08): add/edit/delete, **line-item editor with multi-category split**, balance reconciliation, transfers.
3. **Categorization** (FR-CAT-01..04, 08): manage categories/subcategories, tags, assign per line item.
4. **Multi-currency** (FR-CUR-01..04, 06): base currency, per-transaction currency, manual historical rates, base-amount caching.
5. **Accounts** (FR-ACC): accounts, balances, transfers.
6. **Analytics MVP** (FR-ANL-01..05, 10): dashboard, spend-by-category, over-time, income-vs-expense, global filters, drill-down — charts via **fl_chart**, styled from the shared design tokens ([12](12-design-system-and-ux.md)).
7. **Data & sync** (FR-DAT-01..05, 07; FR-SYNC-01..04): encrypted local DB; offline-first PowerSync working across **all platforms**; per-row **last-write-wins** on `updatedAt` with children keyed to parent; CSV import/export; auto migrations; cloud as the always-on backup.
8. **UI shell**: responsive Material 3 navigation (**NavigationBar** mobile / **NavigationRail** tablet-desktop / drawer), all MVP screens from [06](06-ux-ui-spec.md), light/dark themes.

**Exit criteria:** a user can run their whole finances — enter multi-category transactions in multiple currencies, categorize, see dashboard + 3 core charts with filters & drill-down, import/export CSV — fully offline, with all changes converging across devices when online. NFR-01 perf met on 10k seeded transactions; conflict cases covered by tests (FR-SYNC-03).

## Phase 2 — Scanning (platform-adaptive OCR) + encrypted attachments
**Goal:** capture by document, on-device first, with attachments encrypted and synced. Covers FR-SCAN-*, FR-CAT-05/06.

- `OcrEngine` Dart interface (words + bounding boxes + confidence) with **platform-adaptive on-device** implementations: **ML Kit** (Android), **Apple Vision** (iOS/macOS via platform channel), **Tesseract via FFI** (Windows/Linux), **Tesseract.js / `TextDetector`** (Web). Optional **Supabase Edge Function** cloud fallback (opt-in) — see [05](05-ocr-document-processing.md).
- Ingest: image files (`image_picker`/`file_picker`), camera (`camera`), mobile document scanner (`google_mlkit_document_scanner`), desktop webcam, **PDF** (text path via `syncfusion_flutter_pdf`/`pdfrx`; rasterize-for-OCR path via `pdfrx`/`printing`).
- Pre-processing with `image` (+ `opencv_dart` FFI) for deskew/threshold/crop.
- Document classifier + per-type parsers (receipt/invoice/paycheck), line-item layout reconstruction, reconciliation, confidence scoring.
- **Review screen**: adaptive Flutter split layout with image+overlay, editable fields, confidence highlighting (FR-SCAN-06/11), reusing the Phase 1 line-item editor.
- **Encrypted attachments**: client-side **AES-256-GCM** blobs synced to **Supabase Storage** with a local cache; metadata + OCR text in DB; OCR-text search (FR-SCAN-08). See [09 §2](09-security-privacy.md).
- Auto-categorization rules engine + merchant memory (FR-CAT-05/06).
- Accuracy test harness with labeled fixture corpus ([05 §7](05-ocr-document-processing.md)); resolve ADR-003 default per platform.

**Exit criteria:** scan a printed receipt on at least mobile + one desktop platform → reviewed → saved with itemized multi-category lines & an encrypted attachment that syncs to other devices, meeting the accuracy targets in [05 §1](05-ocr-document-processing.md). Capture works fully offline; attachments upload when online.

## Phase 3 — Deeper analysis & budgets
**Goal:** richer insight. Covers FR-BUD, FR-ANL-06..09, FR-DAT-06, FR-SCAN-10.

- Budgets per category + actual-vs-budget + alerts.
- Advanced visualizations: treemap, calendar heatmap, waterfall, MoM/YoY, top merchants — **fl_chart** plus **syncfusion_flutter_charts / syncfusion_flutter_treemap** where richer chart types are needed, styled from the shared tokens.
- Recurring/subscription detection.
- Recurring transaction templates (FR-CAP-07).
- **PDF report export** (`printing`/`syncfusion_flutter_pdf`).
- Optional online exchange-rate fetch (FR-CUR-05) — explicit, opt-in.
- Per-merchant OCR templates (FR-SCAN-10).

**Exit criteria:** budgets tracked with alerts; all advanced charts live with drill-down across platforms; PDF report exports for a chosen period; new entities sync per Phase 1 rules.

## Phase 4 — v1.0 polish & release
**Goal:** shippable product across all stores. Covers NFR-07/08/11, FR-SEC-03/05, and the GDPR-driven requirements (data export, account deletion) in [09](09-security-privacy.md).

- **Store releases & packaging**: Android **AAB → Google Play**; iOS **App Store/TestFlight**; macOS **notarized .dmg/.pkg + Mac App Store**; Windows **MSIX / Inno Setup (+ optional Microsoft Store)**; Web **PWA** (static hosting + service worker). Optional Fastlane/Codemagic for store deploys.
- First-run onboarding wizard (account creation, **recovery-phrase capture**, data-residency notice).
- **Accessibility** pass: Semantics, screen readers (TalkBack/VoiceOver/Narrator), contrast AA, scalable text/reduce-motion — across mobile/desktop/web.
- **Localization**: EN + CS via `flutter_localizations` + `intl` (ARB), locale-aware number/date formatting.
- **Biometric unlock** (`local_auth`) + configurable **auto-lock** on idle (FR-SEC-03/05).
- **E2E-encryption hardening**: multi-device key wrapping/rotation, recovery-phrase flow, attachment encryption review ([09 §3](09-security-privacy.md)).
- **Performance hardening** to NFR-01/02 on 100k transactions; rollup cache; sync-throughput testing.
- Optional, **opt-in** crash reporting (Sentry) and telemetry; data export & account deletion flows finalized.

**Exit criteria:** signed/notarized builds published (or submission-ready) for Play, App Store, Mac, Windows, and Web PWA; onboarding with recovery phrase; AA-level accessibility on core flows; CS/EN localized; biometric unlock + auto-lock; data export and account deletion working; all NFRs met.

---

## Cross-phase: definition of done (every feature)
- Code in the correct layer; interfaces (ports) in **application**, implementations in **data**; **domain depends on nothing** ([03 §3](03-architecture.md)).
- Unit tests for domain/application logic; **≥ 70% coverage** on domain/application (NFR-09).
- `dart analyze` clean (analyzer/lints as errors in core libs); no `// ignore` without justification.
- **Widget tests** for non-trivial UI and **golden tests** (`alchemist`/`golden_toolkit`) for key components; `integration_test` for critical flows (sync round-trip, scan→save).
- Synced entities include sync columns and have conflict behavior covered by tests (FR-SYNC-03).
- Requirement IDs referenced in the PR; docs updated if behavior changed.
- Manual smoke on the relevant screen on at least one mobile and one desktop/web target.

## Sequencing rationale
- **Sync and encryption land in Phase 0** because retrofitting them is costly and invasive: every synced table needs sync columns and tombstones from day one, and at-rest/in-transit/cloud encryption shapes the data and key-management design. Building the vertical slice as a two-device sync proves the hardest plumbing first.
- Clean **layering** is established in Phase 0 so domain stays framework-agnostic and testable as features grow.
- The **line-item/split model lands in MVP** (not deferred) because categorization, analytics, and later scanning all depend on it — it is the spine of the data model.
- **Scanning (Phase 2)** builds on a solid synced manual model, so OCR output maps onto proven entities and the review screen reuses the line-item editor; encrypted attachments reuse the sync + key-management foundations.
- Heavy/advanced visualizations wait until real data and the aggregation layer exist (Phase 3).
- **Store release, localization, biometrics and encryption hardening** consolidate in Phase 4 once the surface area is stable, avoiding repeated store-submission and notarization churn.

## Tracking
Use the issue tracker with labels per phase and requirement IDs (e.g. `FR-CAP-03`, `FR-SYNC-03`). A milestone per phase; the acceptance criteria above are the milestone exit checklists. CI must be green (`dart analyze`, tests, golden tests) on the platform matrix before a milestone closes.
