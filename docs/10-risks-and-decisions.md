# Risks & Decision Log (ADRs)

**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform

This log reflects the re-platform of Ledgerly from a Windows-only C#/.NET/WinUI local-only app to a **cross-platform Dart/Flutter** app (web, mobile, desktop) that is **offline-first and cloud-backed with encrypted multi-device sync**. Several earlier decisions are explicitly superseded below; the reversal of ADR-001 (Flutter over WinUI) is the pivotal one.

---

## Part A — Risk register

Likelihood (L) / Impact (I): Low / Med / High.

| ID | Risk | L | I | Mitigation |
|----|------|---|---|------------|
| R-01 | **OCR accuracy** on messy receipts is below user expectation. | High | High | Mandatory human review (FR-SCAN-06); strong preprocessing (`image`/`opencv_dart`); platform-adaptive engines (ML Kit / Apple Vision / Tesseract / Tesseract.js) behind `OcrEngine`; confidence flags; graceful fallback to single-line draft; accuracy test harness ([05 §7](05-ocr-document-processing.md)). Set expectations in onboarding. |
| R-03 | **Line-item layout parsing** is brittle across vendors. | High | Med | Generic row/column reconstruction + per-merchant templates (FR-SCAN-10); always reconcile to total; never auto-save. |
| R-04 | **Multi-currency rounding / FX correctness** bugs cause wrong totals. | Med | High | `decimal` + Money value object; banker's rounding at boundaries only; historical rate per date; unit tests on conversion edge cases (ADR-005). |
| R-06 | **Performance** degrades on large datasets (100k+ tx, big attachments) or under sync load. | Med | Med | SQL-side aggregation, indexes, list virtualization, rollup cache, async I/O, reactive Drift streams; sync-throughput testing; perf tested against seeded data (NFR-01/02). |
| R-07 | **PDF variety** (scanned vs digital, multi-page) breaks ingest. | Med | Med | Detect text layer (`syncfusion_flutter_pdf`/`pdfrx`) vs rasterize (`pdfrx`/`printing`); per-page progress; fallback to manual. |
| R-08 | **Scope creep** (bank feeds, multi-user, web parity edge cases) delays v1. | Med | Med | Non-goals fixed in PRD; phased roadmap ([08](08-implementation-roadmap.md)); data/sync model leaves room without building now. |
| R-10 | **Data loss** on crash, bad migration, or sync error. | Low | High | WAL + transactions; automatic pre-migration snapshot; cloud as always-on backup; encrypted local export/import; tested backup/restore and sync round-trip (NFR-05/13). |
| R-11 | **Solo-project maintenance / bus factor.** | Med | Med | Clear layered architecture, tests, golden tests, and this doc set; mainstream stack (Flutter/Dart/Supabase) for future maintainability. |
| R-13 | **Sync-conflict correctness** — concurrent multi-device edits produce wrong or lost data. | Med | High | Per-row **last-write-wins** on `updatedAt` (UTC), version/clock, children keyed to parent (FR-SYNC-03); soft-delete tombstones; deterministic conflict tests; PowerSync handles ordering/retries (ADR-010). |
| R-14 | **Web encryption / OPFS maturity** — browser storage + WebCrypto limitations weaken or complicate web at-rest encryption. | Med | Med | Drift WASM + OPFS with non-extractable WebCrypto key; app-level field encryption where SQLCipher is unavailable; treat web as a first-class but separately-tested target; feature-detect and degrade gracefully ([09 §2](09-security-privacy.md)). |
| R-15 | **Cloud cost & vendor lock-in** — Supabase/PowerSync usage costs grow; migration away is hard. | Med | Med | Keep domain/application layers backend-agnostic behind ports (`SyncService`, repositories); standard Postgres schema; monitor usage/cost per phase; PowerSync/Supabase are portable Postgres-based; alternatives recorded (ADR-002/010). |
| R-16 | **Multi-platform OCR variance** — different engines per platform give inconsistent results. | Med | Med | Single `OcrEngine` contract (words+boxes+confidence); per-platform accuracy harness; document expected differences; optional cloud fallback for parity on hard docs (ADR-003). |
| R-17 | **App-store review / notarization friction** — Play/App Store/Mac notarization/Windows signing rejections delay release. | Med | Med | Start store accounts, signing, and notarization early in Phase 4; comply with data-safety/privacy disclosures; Fastlane/Codemagic to automate; budget review buffer ([08 Phase 4](08-implementation-roadmap.md)). |
| R-18 | **Key-loss vs cloud-recovery tension** — users expect cloud accounts to be recoverable, but client-side E2E keys are not. | Med | High | **Recovery phrase** makes a forgotten password recoverable; clear onboarding that losing both = unrecoverable; recovery-phrase capture in onboarding; honest user-facing copy ([09 §3/§10](09-security-privacy.md)). |
| R-19 | **RLS misconfiguration leaking data** across tenants. | Low | High | RLS keyed to `auth.uid()` on every synced table; **positive + cross-tenant-negative policy tests** before exposing a table; Supabase advisors/lints reviewed each phase; least-privilege keys (ADR-002, [09 §8](09-security-privacy.md)). |

> Retired since v0.1: R-02 (WinUI 3 immaturity), R-05 (re-cast into R-18/R-19 and ADR-012), R-09 (HEIC on Windows), R-12 (Tesseract on Windows) — all artifacts of the Windows-only/WinUI direction. New: R-13..R-19.

## Part B — Architecture Decision Records (ADRs)

### ADR-001 — UI framework: Flutter (Material 3), one codebase across web/mobile/desktop
**Status:** Accepted (2026-06-18). **Supersedes the previous ADR-001** ("WinUI 3 primary, WPF fallback; Flutter rejected").
**Context:** The product requirement changed from a Windows-only native app to a **true cross-platform** app — iOS, Android, Web (PWA), Windows, macOS (Linux best-effort) — from a single codebase. The old decision rejected Flutter in favor of a .NET-native, Windows-only direction.
**Decision:** Build on **Flutter (stable channel) + Material 3** with a custom design-token theme via `ThemeExtension`. **This reverses the earlier rejection of Flutter.** Reason for the reversal: a single Dart/Flutter codebase is the only option evaluated that delivers native-quality UI on mobile, desktop, **and** web without maintaining parallel UIs, which the multi-platform requirement makes mandatory.
**Consequences:** One codebase, broad reach, strong widget/test/golden ecosystem; platform-adaptive UI and platform-specific plugins (OCR, biometrics, camera) where needed; loses native-WinUI Fluent look (acceptable — Material 3 + tokens give an intentional, consistent design).
**Alternatives:** WinUI 3 / WPF (Windows-only — fails the requirement); Electron/Tauri + web stack (heavier desktop, weaker mobile); React Native / KMP-Compose (no first-class web-from-one-codebase story matching Flutter for this app).

### ADR-002 — Storage: offline-first encrypted Drift/SQLite + Supabase Postgres
**Status:** Accepted (2026-06-18). **Supersedes the previous ADR-002** ("EF Core + SQLCipher, local-only").
**Context:** Each device must work fully offline with a local relational DB, yet converge across devices via the cloud, with encryption at every tier.
**Decision:** **Drift over SQLite** on-device (type-safe, reactive `Stream` queries, migrations), encrypted via `sqlite3` + `sqlcipher_flutter_libs` (native) and **WASM + OPFS** (web); **Supabase Postgres** as the cloud mirror with **Row-Level Security**; sync between them via PowerSync (ADR-010).
**Consequences:** Offline-first by default; reactive UI; standard Postgres schema (eases portability, R-15); requires sync columns/tombstones on every synced table ([04](04-data-model.md), [09 §7](09-security-privacy.md)).
**Alternatives:** Plaintext SQLite + field encryption (leaks structure); Isar/ObjectBox (weaker relational/migration story); a hosted SQL backend without offline-first (fails the offline requirement).

### ADR-003 — OCR engine: platform-adaptive on-device, optional cloud fallback
**Status:** Proposed (decide per platform during Phase 2 via accuracy harness).
**Context:** OCR must work offline and respect privacy across five platforms with differing native capabilities.
**Decision:** A single **`OcrEngine`** Dart interface (words + bounding boxes + confidence) with **platform-adaptive on-device** implementations: **ML Kit** (Android), **Apple Vision** (iOS/macOS), **Tesseract via FFI** (Windows/Linux), **Tesseract.js / `TextDetector`** (Web). An **opt-in Supabase Edge Function** provides cloud fallback for hard documents only.
**Consequences:** Offline + private by default; best native engine per platform; some cross-platform variance (R-16), managed by the shared contract and per-platform accuracy harness ([05 §7](05-ocr-document-processing.md)).
**Alternatives:** Single cross-platform engine everywhere (lower accuracy on some platforms); cloud-only OCR (violates offline/privacy defaults).

### ADR-004 — Attachment storage: Supabase Storage (client-side encrypted) + local cache
**Status:** Accepted (2026-06-18). **Supersedes the previous ADR-004** ("encrypted local files vs DB BLOBs").
**Context:** Original documents must be stored encrypted, linked to transactions, and available on every device.
**Decision:** Encrypt attachments **client-side with AES-256-GCM** before upload and store the opaque blobs in **Supabase Storage**, with a **local encrypted cache** for offline access; the DB holds metadata + OCR text. The server never sees plaintext attachments.
**Consequences:** Multi-device access, true end-to-end protection for the most sensitive content, lean DB; depends on key management (ADR-012); needs cache eviction policy.
**Alternatives:** DB BLOBs (bloats sync payloads); server-side-only encryption (operator could read content); local-only files (no multi-device).

### ADR-005 — Money representation: decimal + Money value object
**Status:** Accepted (unchanged in principle).
**Context:** Financial correctness; multi-currency.
**Decision:** Represent money with the **`decimal`** package wrapped in a **`Money(amount, currencyCode)`** value object; store as a **TEXT decimal string** in Drift via a `TypeConverter` (scaled-integer minor units noted as the alternative); banker's rounding applied only at persistence/display boundaries; FX via historical per-date rates with cached base amounts.
**Consequences:** No float drift; currency-safe arithmetic; clear conversion semantics ([04 §3](04-data-model.md)).

### ADR-006 — Categorization at line-item granularity
**Status:** Accepted (unchanged).
**Context:** Bills can contain items from multiple categories (core requirement FR-CAT-04).
**Decision:** Categorize **line items**, not whole transactions. A "split" is simply line items with different category IDs; analytics aggregate at line level.
**Consequences:** Naturally supports multi-category bills, accurate category analytics, and OCR line-item mapping. Slightly more entry effort for simple expenses — mitigated by a single-category quick mode ([06 §2.4](06-ux-ui-spec.md)).

### ADR-007 — Cloud-backed offline-first with encrypted sync and opt-in telemetry
**Status:** Accepted (2026-06-18). **Supersedes the previous ADR-007** ("offline-first, no cloud, no network").
**Context:** The product value shifted from "no network at all" to "seamless multi-device sync **without** sacrificing privacy."
**Decision:** Be **offline-first** (full local function) **and** cloud-backed: changes sync, encrypted, when online. Encryption at rest on device, TLS in transit, encryption at rest in the cloud, RLS tenant isolation, and **client-side E2E encryption** for attachments/sensitive payloads. Telemetry and crash reporting are **opt-in only** and never include financial data.
**Consequences:** Multi-device + cloud backup; introduces hosting and therefore **GDPR obligations** (controller/processor, residency, erasure, portability — [09 §9](09-security-privacy.md)); sync-correctness and key-loss tensions to manage (R-13, R-18).
**Alternatives:** Local-only (old model — fails the multi-device requirement); always-online cloud app (fails offline-first).

### ADR-008 — Stack baseline: Flutter/Dart 3, Supabase, Riverpod, Drift, PowerSync, fl_chart
**Status:** Accepted (2026-06-18). **Supersedes the previous ADR-008** (".NET 10 / WinUI 3 / EF Core 10 baseline").
**Context:** The re-platform requires a coherent, current, cross-platform baseline.
**Decision:** Target **Flutter (latest stable channel) / Dart 3.x**; **Supabase** (Postgres/Auth/Storage/Realtime/Edge Functions/RLS); **Riverpod 2.x** (state/DI, ADR-011); **Drift** (local DB, ADR-002); **PowerSync** (sync, ADR-010); **fl_chart** (charts, with Syncfusion for advanced types); **freezed + json_serializable** (models); **go_router** (navigation); **flutter_secure_storage**, **local_auth**, **intl/flutter_localizations**. Pin versions and re-audit (`dart pub outdated`, Supabase advisors) at the start of every phase.
**Consequences:** Mainstream, well-supported, cross-platform; replaces the entire .NET/WinUI baseline. Pinned baseline tracked in [03 §2.1](03-architecture.md).
**Alternatives:** .NET MAUI (weaker web), other BaaS (Firebase — non-relational, weaker offline-Postgres story).

### ADR-009 — Design system: Material 3 + ThemeExtension tokens
**Status:** Accepted (2026-06-18). **Supersedes the previous ADR-009** ("WinUI 3 Fluent + token layer").
**Context:** The UI must feel clean, modern, and trustworthy across platforms with a single token source shared by widgets and charts.
**Decision:** Adopt **Material 3** with design tokens via Flutter **`ThemeExtension`** + `ColorScheme.fromSeed` (light/dark/high-contrast; dynamic color on Android 12+), shared with charts; documented components, motion, and accessibility — see [12-design-system-and-ux.md](12-design-system-and-ux.md).
**Consequences:** Consistent, accessible UI; one source of truth for spacing/color/type that ViewModels and charts share; clear "done" bar per screen.

### ADR-010 — Sync engine: PowerSync (new)
**Status:** Accepted (2026-06-18); confirm finally early in build.
**Context:** Offline-first multi-device sync between local SQLite and Supabase Postgres needs robust ordering, retries, conflict handling, and partial replication.
**Decision:** Use **PowerSync** as the primary sync engine (Postgres↔SQLite, sync rules per user), with per-row **last-write-wins** on `updatedAt` and soft-delete tombstones (FR-SYNC-03).
**Consequences:** Avoids hand-building reliable sync; integrates with Supabase + Drift; introduces a dependency and cost factor (R-15); conflict semantics constrained to LWW (acceptable for single-user-multi-device).
**Alternatives:** **Custom last-write-wins sync** over Supabase REST (full control, high risk/effort — R-13); **Supabase Realtime + change-log** (more plumbing for offline catch-up/conflict). Recorded as fallbacks if PowerSync cost/fit disappoints.

### ADR-011 — State management & DI: Riverpod (new)
**Status:** Accepted (2026-06-18).
**Context:** The app needs testable, compile-safe state management and dependency injection across many features, wiring interfaces to implementations at a composition root.
**Decision:** Use **Riverpod 2.x** (with `riverpod_generator`); MVVM-style ViewModels as `Notifier`/`AsyncNotifier`; repositories/services injected as providers at the composition root.
**Consequences:** Compile-safe, mockable (`mocktail`), no `BuildContext` dependency for logic, good async/stream ergonomics for Drift; team must follow code-gen conventions.
**Alternatives:** **Bloc** (more ceremony/boilerplate for this app's needs); **Provider** (older, less type-safe, superseded by Riverpod); **GetX** (rejected — opinionated, weaker testability).

### ADR-012 — Multi-device end-to-end encryption & key management (new)
**Status:** Accepted (2026-06-18).
**Context:** Sensitive data (attachments, designated payloads) must remain readable across the user's devices but **not** to the server, while keeping the account recoverable enough to be usable.
**Decision:** Derive a key from the user's **passphrase via Argon2id**; use it to wrap a **content encryption key (CEK)** for client-side **AES-256-GCM**; **wrap the CEK for multi-device** so any authenticated device with the passphrase can unwrap it; provide a **recovery phrase** that also wraps the CEK so a forgotten password is recoverable. The plaintext CEK never leaves the device. Losing **both** password and recovery phrase = unrecoverable.
**Consequences:** True E2E for sensitive data with multi-device convenience; introduces the key-loss-vs-recovery tension (R-18) and onboarding burden (capture recovery phrase); password change re-wraps rather than re-encrypts content. Details in [09 §3](09-security-privacy.md).
**Alternatives:** Server-managed keys (operator could read data); device-only keys with no wrapping (no multi-device); no recovery phrase (forgotten password = total loss).

## Part C — Open questions to resolve before/early in build
1. Confirm working **app name** (currently "Ledgerly") and base currency default.
2. **ADR-010:** final call on **PowerSync vs custom last-write-wins sync** (vs Supabase Realtime), validated against cost and conflict-correctness on real workloads.
3. **ADR-003:** default OCR engine **per platform** after accuracy measurement; whether to ship the opt-in cloud fallback at v1.
4. **ADR-012 / Argon2id params:** memory, iterations, and parallelism (device-tier vs security trade-off), plus recovery-phrase format and length.
5. **Data residency region:** confirm the Supabase region (preferring EU) and document it in the privacy policy ([09 §5/§9](09-security-privacy.md)).
6. **Store distribution specifics:** signing/notarization and update strategy per platform — Play (AAB), App Store/TestFlight, Mac App Store vs notarized DMG, Windows MSIX vs Microsoft Store, Web PWA hosting ([08 Phase 4](08-implementation-roadmap.md)).
7. **Cloud cost & lock-in budget (R-15):** projected Supabase/PowerSync costs at expected scale and the exit/portability plan.
