# Technical Architecture

**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform

---

## 1. Architectural overview

Ledgerly is a **single Dart/Flutter codebase** that ships to **iOS, Android, Web (PWA), Windows, and macOS** (Linux best-effort/dev only). It follows **clean, feature-first layering** with an **offline-first** runtime: every device keeps a full **encrypted local SQLite database (Drift)** that is the working store, and changes **sync to a Supabase Postgres cloud backend via PowerSync** whenever the network is available. All devices converge; the app is fully usable offline.

This is a deliberate reversal of the original local-only Windows/.NET/WinUI design (see ADR-001 and ADR-007 in [10-risks-and-decisions.md](10-risks-and-decisions.md)). Hosting user data in the cloud means GDPR controller/processor obligations, data residency, account deletion, and data export now apply — see [09-security-privacy.md](09-security-privacy.md).

> **Version policy:** target the **latest stable Flutter (stable channel) and Dart 3.x**. Pin exact dependency versions in `pubspec.yaml` with a committed `pubspec.lock` (and `melos.yaml` at the workspace root); re-audit each phase with `flutter pub outdated` and `dart pub deps`. See [§2.1](#21-pinned-baseline-verified-2026-06-18).

```
┌────────────────────────────────────────────────────────────────────┐
│  Presentation (features/)                                           │
│   Flutter widgets (Material 3)  ──watch──  Riverpod ViewModels      │
│   (Notifier / AsyncNotifier)    ──call───  Application services     │
├────────────────────────────────────────────────────────────────────┤
│  Application (application/)                                         │
│   Services / use-cases + repository interfaces (PORTS)             │
│   TransactionService · ScanService · CategorizationService ·       │
│   AnalyticsService · BudgetService · CurrencyService · SyncService  │
├────────────────────────────────────────────────────────────────────┤
│  Domain (domain/)  — pure Dart, depends on NOTHING                 │
│   Entities · Value objects (Money) · invariants & rules           │
├────────────────────────────────────────────────────────────────────┤
│  Data (data/)  — adapters implementing the ports                   │
│   local/     Drift tables · DAOs · migrations · at-rest encryption  │
│   remote/    Supabase client · PowerSync sync engine               │
│   ocr/       OcrEngine impls per platform                          │
│   documents/ PDF/image parsing · classifiers · parsers            │
│   io/        CSV/PDF import-export · backup                        │
└────────────────────────────────────────────────────────────────────┘
        Riverpod wires impls → ports at the composition root.
```

**Design principles**

- **Offline-first** — the local Drift/SQLite DB is the source of truth at runtime; nothing blocks on the network. Sync is a background convergence process, not a request/response dependency.
- **Clean layering** — dependencies point inward: `features → application → domain` and `data → application/domain`. **Domain depends on nothing** (no Flutter, no Drift, no Supabase). UI never touches the database; it goes through application services.
- **Dependency inversion via Riverpod** — services, repositories, OCR engines, and rate providers are abstract classes (ports) in `application`, implemented in `data`, and bound by Riverpod providers at the composition root, so each is swappable and testable.
- **Reactive by default** — Drift exposes `Stream` queries; ViewModels expose `AsyncValue` state; the UI rebuilds when data changes (including changes arriving via sync).
- **Encrypted everywhere** — at rest on device (SQLCipher/app-level), in transit (TLS), at rest in cloud (Postgres + Storage), plus **client-side AES-256-GCM** for attachments and sensitive payloads.
- **Off-UI-thread heavy work** — OCR, PDF rasterization, and parsing run in **isolates**; DB access is async.

## 2. Technology stack

| Concern | Choice | Notes |
|---------|--------|-------|
| Language / runtime | **Dart 3.x / Flutter (stable channel, latest stable)** | One codebase across web/mobile/desktop. |
| UI framework | **Flutter + Material 3** | Custom design-token theme via `ThemeExtension`; responsive/adaptive layouts. See [12-design-system.md](12-design-system-and-ux.md). |
| State mgmt / DI | **Riverpod 2.x** (`riverpod_generator` code-gen) | MVVM-style ViewModels using `Notifier`/`AsyncNotifier`; providers are the DI container. |
| Navigation | **go_router** | URL-based routes, deep links, web addresses, route guards (auth/lock). |
| Local DB / ORM | **Drift** over SQLite | Type-safe, reactive `Stream` queries, migrations. At-rest encryption via `sqlite3` + `sqlcipher_flutter_libs`; web via Drift **WASM + OPFS**. |
| Cloud backend | **Supabase** | Postgres, Auth, Storage, Realtime, Edge Functions, Row-Level Security. |
| Sync engine | **PowerSync** | Offline-first Postgres↔SQLite sync (PRIMARY). Alternatives: custom last-write-wins, or Supabase Realtime + change-log (ADR-010). |
| Auth | **Supabase Auth** | Email+password, OAuth (Apple/Google), magic link; JWT + refresh tokens in secure storage. |
| Local unlock / biometrics | **local_auth** | Face ID / Touch ID / Android biometrics / Windows Hello; web falls back to passphrase. |
| Secure key storage | **flutter_secure_storage** | Keychain / Keystore / DPAPI / libsecret; web uses a non-extractable WebCrypto key. |
| Models / immutability | **freezed** + **json_serializable** | Entities, value objects, DTOs. |
| Money | **`decimal`** package + a **Money** value object | Banker's rounding at boundaries only (ADR-005). |
| OCR abstraction | **`OcrEngine`** Dart interface | Platform-adaptive impls (ML Kit / Apple Vision / Tesseract / Tesseract.js). See [05-ocr-document-processing.md](05-ocr-document-processing.md). |
| PDF | **syncfusion_flutter_pdf** (or `pdfrx`) for text; **pdfrx/pdfx/printing** to rasterize | Extract embedded text; rasterize scanned pages for OCR. |
| Image preprocessing | **`image`** (pure Dart) + **`opencv_dart`** (FFI) | Deskew, threshold, crop, denoise. |
| Charts | **fl_chart** (primary, pure-Dart, all platforms) | **syncfusion_flutter_charts** + **syncfusion_flutter_treemap** for advanced (treemap/heatmap); `graphic` as alt. |
| Localization | **flutter_localizations + intl** (ARB) | EN + CS; locale-aware `NumberFormat`/`DateFormat`. |
| Logging | **logger** / **talker** (local files via `path_provider`) | Optional **opt-in** Sentry crash reporting. |
| Validation | custom validators + **form_builder_validators** | Input/domain validation. |
| Camera / scan | **camera**, **image_picker**, **google_mlkit_document_scanner** (mobile), **file_picker** (all) | Webcam on desktop. |
| Tests | **flutter_test**, **mocktail**, **integration_test**, golden (**alchemist**/golden_toolkit) | **patrol** optional for E2E. |
| CI/CD | **GitHub Actions** multi-platform matrix | **Fastlane**/**Codemagic** optional for store deploys. |
| Packaging | AAB → Play; App Store/TestFlight; notarized .dmg/.pkg + Mac App Store; **MSIX**/Inno Setup (+ optional Microsoft Store); Web **PWA** | Single codebase, per-platform bundles. |

> See [10-risks-and-decisions.md](10-risks-and-decisions.md) for the ADRs justifying these choices (ADR-001, 002, 003, 004, 008, 010, 011, 012).

### 2.1 Pinned baseline (verified 2026-06-18)

Pin exact versions in `pubspec.yaml`, commit `pubspec.lock`, and centralize shared constraints via the **melos** workspace. Target latest stable; re-check with `flutter pub outdated` (and any advisory scan) at the start of each phase.

| Package / SDK | Pinned baseline |
|---------------|-----------------|
| Flutter SDK | **latest stable (stable channel)**; `environment.sdk` = Dart **^3.x** |
| flutter_riverpod / riverpod_annotation / riverpod_generator | **2.x** |
| go_router | latest stable |
| drift / drift_dev / sqlite3 / sqlcipher_flutter_libs | latest stable (Drift 2.x) |
| supabase_flutter | latest stable (2.x) |
| powersync (+ `powersync_drift` bridge) | latest stable |
| freezed / freezed_annotation / json_serializable / build_runner | latest stable |
| decimal | latest stable |
| local_auth / flutter_secure_storage | latest stable |
| fl_chart | latest stable; syncfusion_flutter_charts / _treemap as needed |
| syncfusion_flutter_pdf / pdfrx / printing | latest stable |
| image / opencv_dart | latest stable |
| google_mlkit_text_recognition / google_mlkit_document_scanner | latest stable (mobile) |
| camera / image_picker / file_picker / path_provider | latest stable |
| intl / flutter_localizations | bundled / latest stable |
| logger / talker (+ optional sentry_flutter) | latest stable |
| mocktail / integration_test / alchemist / patrol | latest stable |
| melos | latest stable (workspace tooling) |

> **Rationale for the platform bump from the original .NET 10 / WinUI 3 baseline:** the product requirement changed from Windows-only/local to true multi-platform + cloud sync. A single Flutter codebase covers all five targets; Drift + PowerSync + Supabase provide the offline-first encrypted-sync runtime. Tracked as ADR-001 / ADR-008 (and new ADR-010/011/012) in [10-risks-and-decisions.md](10-risks-and-decisions.md).

## 3. Offline-first sync architecture

Ledgerly is **offline-first**: the **local Drift/SQLite database is the working store** for all reads and writes. The UI is driven by reactive Drift `Stream` queries and never blocks on the network.

```
┌─────────── Device (offline-capable) ────────────┐         ┌──────── Cloud (Supabase) ────────┐
│  Flutter UI  ⇄  Riverpod VMs  ⇄  Services        │         │  Postgres (RLS by auth.uid())     │
│        │                                         │         │  ▲   mirrored schema               │
│        ▼ reactive streams                        │         │  │                                 │
│  Drift / SQLite (encrypted, WORKING STORE)       │         │  │  PowerSync service               │
│        ▲                                         │  HTTPS  │  │  (sync rules per user)           │
│        │  local writes (immediate)               │ ◀─────▶ │  ▼                                 │
│  PowerSync client  ──upload queue──▶  ─────────────────────▶  apply + fan-out to other devices  │
│  AttachmentStore (local cache) ──encrypted blob──────────▶  Supabase Storage (per-user bucket)  │
└──────────────────────────────────────────────────┘         └───────────────────────────────────┘
```

**How it works**

1. **Local writes are immediate.** Services write to Drift; the UI updates instantly from the reactive stream. PowerSync records the change in a local upload queue.
2. **Upload.** When online, PowerSync uploads queued changes to Supabase Postgres (applied through PowerSync write hooks / Edge Functions, subject to RLS).
3. **Download.** PowerSync streams the user's rows (per the sync rules in [04-data-model.md](04-data-model.md)) down into the local Drift DB; reactive queries refresh the UI on all devices.
4. **Attachments** are encrypted client-side (AES-256-GCM), cached locally, and uploaded to a per-user **Supabase Storage** bucket; the DB row holds metadata + OCR text + storage key (ADR-004).

**Conflict resolution**

- **Per-row last-write-wins on `updatedAt` (UTC).** Each synced row carries `id` (UUID), `userId`, `updatedAt`, a `deleted` tombstone, and a `version`/clock. The newer `updatedAt` wins.
- **Tombstones, not hard deletes** — deletes set `deleted = true` so the deletion propagates; a purge job removes tombstoned rows after the retention window.
- **Children keyed to parents** — `LineItem`s and `LineItemTag`s converge against their parent `Transaction`; a re-arrived parent re-anchors its children. The Σ(line amounts) invariant is re-validated on the device after merge.
- Conflicts and clock skew are detailed in [04-data-model.md](04-data-model.md) §Conflict resolution.

**What works offline vs needs network**

| Works fully offline | Needs network |
|---------------------|---------------|
| All capture/edit (transactions, line items, splits), categories, accounts | Initial sign-in / token refresh (cached session works offline) |
| On-device OCR + parsing + categorization rules | Cross-device convergence (sync upload/download) |
| Analytics, budgets, charts (computed in-DB locally) | Attachment upload/download to Supabase Storage (cached copies work offline) |
| CSV import/export, local backup | Optional cloud OCR fallback (Edge Function) |
| Local unlock (biometric/passphrase) | Optional exchange-rate fetch; account deletion / data export |

## 4. Solution / project structure

A single Flutter app inside an optional **melos** workspace. Layer boundaries are enforced by directory and import discipline (lint rules forbid `domain` importing Flutter/Drift/Supabase).

```
ledgerly/                         # melos workspace (optional monorepo)
├─ app/                           # Flutter application
│  └─ lib/
│     ├─ main.dart
│     └─ src/
│        ├─ core/                 # theming/tokens, router (go_router), DI, l10n, utils
│        ├─ domain/               # entities, value objects (Money), rules — pure Dart
│        ├─ application/          # services/use-cases + repository interfaces (ports)
│        ├─ data/
│        │  ├─ local/             # Drift tables, DAOs, migrations, encryption
│        │  ├─ remote/            # Supabase client, sync engine (PowerSync)
│        │  ├─ ocr/               # OcrEngine implementations per platform
│        │  ├─ documents/         # PDF/image parsing, classifiers, parsers
│        │  └─ io/                # CSV/PDF import-export, backup
│        └─ features/             # one folder per feature: view (widgets) + viewmodel (Riverpod Notifier)
│           ├─ dashboard/  transactions/  scan/  categories/
│           └─ analytics/  budgets/  accounts/  settings/  auth/  lock/
├─ packages/                      # optional shared packages (e.g. domain, design_system)
└─ docs/                          # these documents
```

**Dependency direction:** `features → application → domain`; `data → application/domain`. **Domain references nothing.** Riverpod composes `data` implementations onto `application` ports only at the composition root (`core/di`).

## 5. Key application services (ports)

Each port is an **abstract class** declared in `application/`, implemented in `data/`, and consumed by Riverpod ViewModels in `features/`. Signatures below are illustrative.

```dart
// application/ports — abstract classes (interfaces)

abstract class TransactionService {
  Stream<List<Transaction>> watch(TransactionQuery query);
  Future<Transaction> upsert(Transaction tx);              // header + line items
  Future<void> softDelete(String id);                       // sets tombstone
  Future<void> reconcileBalances(String accountId);
}

abstract class ScanService {
  // ingest → preprocess → OCR → classify → parse → suggest → draft
  Future<DraftTransaction> scan(SourceDocument source);
}

abstract class OcrEngine {
  Future<OcrResult> recognize(Uint8List image);             // words + boxes + confidence
}

abstract class DocumentParser {
  ParsedDocument parse(OcrResult ocr, DocType type);        // header fields + line items
}

abstract class CategorizationService {
  Future<List<CategorySuggestion>> suggest(LineItem item);
  Future<int> reapplyRules({String? transactionId});
}

abstract class CurrencyService {
  Future<Money> toBase(Money amount, DateTime onDate);
  Future<void> recomputeBaseAmounts();                      // on base-currency change
}

abstract class AnalyticsService {
  Stream<List<CategoryTotal>> spendByCategory(DateRange range);
  Stream<List<PeriodTotal>> spendByPeriod(Period period, DateRange range);
}

abstract class BudgetService {
  Stream<List<BudgetStatus>> watchActualVsBudget(YearMonth month);
  Future<Budget> upsert(Budget budget);
}

abstract class BackupService {
  Future<File> exportEncrypted();
  Future<void> restore(File backup);
  Future<bool> verifyIntegrity();
}

abstract class ImportExportService {
  Future<ImportReport> importCsv(File file, CsvMapping mapping);
  Future<File> exportCsv(TransactionQuery query);
  Future<File> exportPdfReport(ReportSpec spec);
}

abstract class AttachmentStore {
  Future<Attachment> put(Uint8List bytes, AttachmentMeta meta); // client-side encrypt → cache → upload
  Future<Uint8List> get(String attachmentId);                   // local cache, else Storage
}

abstract class SyncService {
  Stream<SyncStatus> watchStatus();                         // connected/uploading/idle/error
  Future<void> trigger();                                   // opportunistic sync
}

abstract class AuthService {
  Stream<AuthState> watch();                                // Supabase Auth session
  Future<void> signIn(Credentials c);
  Future<void> signOut();
}

abstract class AppLockService {
  Future<bool> unlock();                                    // biometric (local_auth) or passphrase
  void armAutoLock(Duration idle);
}
```

## 6. Scan pipeline (high level)

```
File/Camera/Scanner ─▶ Ingest ─▶ Preprocess (deskew/threshold) ─▶ OcrEngine (text+boxes)
                    ─▶ Classify doc type ─▶ Parse (header + line items) ─▶ Suggest categories
                    ─▶ Draft transaction ─▶ [Review screen / user edits] ─▶ Save + encrypt & attach doc
```

`OcrEngine` is platform-adaptive (on-device first, offline): ML Kit (Android), Apple Vision (iOS/macOS), Tesseract via FFI (Windows/Linux), Tesseract.js/WASM (Web), with an optional opt-in Supabase **Edge Function** cloud fallback. CPU-heavy stages run in **isolates**. Full design, heuristics, and accuracy strategy in [05-ocr-document-processing.md](05-ocr-document-processing.md).

## 7. Threading & performance

- **UI thread renders and binds only.** Services are `async`; heavy CPU work (OCR, PDF rasterization, image preprocessing, bulk parsing/import) runs in **isolates** (`Isolate.run` / `compute`) with progress + cancellation.
- **Async DB.** Drift queries are async and stream-based; the UI subscribes to reactive `Stream`s and rebuilds on change (including sync-driven changes).
- **SQL-side aggregation.** Analytics use Drift query builders / custom SQL with `GROUP BY` and aggregates rather than materializing all rows; results cached per filter set.
- **Virtualized lists/grids.** Long transaction lists and chart-feeding queries use **slivers** (`SliverList`/`SliverGrid`, `ListView.builder`) so only visible rows are built.
- **Indices** on `Transaction(date)`, `Transaction(merchantId)`, `Transaction(accountId)`, `LineItem(transactionId)`, `LineItem(categoryId)` (see [04-data-model.md](04-data-model.md)).
- **Sync is incremental and backgrounded** — PowerSync streams deltas; it never blocks interaction.

## 8. Configuration & storage locations

Resolved via **`path_provider`** per platform; the local DB and caches live in the app-support directory.

| Platform | DB / app-support location | Attachment cache | Secure key store |
|----------|---------------------------|------------------|------------------|
| Windows | `getApplicationSupportDirectory()` (under `%APPDATA%\Ledgerly`) | same root `attachments/` | DPAPI (flutter_secure_storage) |
| macOS | `~/Library/Application Support/Ledgerly` | `attachments/` | Keychain |
| iOS | app sandbox Application Support | sandbox `attachments/` | Keychain |
| Android | app-specific internal storage | internal `attachments/` | Keystore |
| Web | Drift **WASM + OPFS** (IndexedDB fallback) | OPFS-backed cache | non-extractable WebCrypto key |
| Linux (dev) | `~/.local/share/Ledgerly` (libsecret) | `attachments/` | libsecret |

- `ledgerly.db` — encrypted SQLite (SQLCipher on native; OPFS-stored WASM DB on web, app-level encryption).
- `attachments/` — client-side-encrypted blobs, cached locally and synced to a per-user Supabase Storage bucket.
- `logs/` — local rolling logs (`logger`/`talker`); no network sink unless crash reporting is opt-in.
- `backups/` — local snapshots + user-chosen export path; cloud sync is the primary durability mechanism.
- Settings: a `settings` table in the DB (synced) + non-sensitive device-local prefs.

## 9. Build, test, CI

- **Local build:** `flutter run` / `flutter build <target>` on the latest stable SDK; codegen via `dart run build_runner build` (Riverpod, Drift, freezed). Workspace tasks via **melos**.
- **CI (GitHub Actions, multi-platform matrix):** `flutter pub get` → `dart run build_runner build` → `flutter analyze` → `flutter test` (unit + golden) → `integration_test` → per-platform build (AAB/IPA/MSIX/.dmg/web). Optional store deploy via Fastlane/Codemagic.
- **Quality gates:** `flutter analyze` with a strict lint set (including layering rules), warnings-as-errors in CI for core packages, golden tests for key widgets, and a sync vertical-slice integration test (two simulated devices converge).

## 10. Open architectural questions

- **Sync engine** — PowerSync (PRIMARY, ADR-010) vs custom last-write-wins vs Supabase Realtime + change-log; revisit if cloud cost or write-conflict semantics demand it.
- **Web encryption & OPFS maturity** — Drift WASM + OPFS durability and WebCrypto key handling on web need validation in Phase 0/1.
- **Attachment encryption boundary** — per-file AES-256-GCM keys wrapped by the user key vs envelope encryption; sync of large blobs vs lazy fetch (ADR-004).
- **Default OCR per platform** and the opt-in cloud OCR fallback threshold (ADR-003).
- **Data residency** — Supabase region selection (prefer EU) and its interaction with right-to-erasure (ADR-007); see [09-security-privacy.md](09-security-privacy.md).

These are tracked in [10-risks-and-decisions.md](10-risks-and-decisions.md) and resolved before the relevant phase begins.
