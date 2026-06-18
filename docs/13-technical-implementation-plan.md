# Technical Implementation Plan

**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform

> This is the **authoritative engineering plan** for building Ledgerly as a single
> Dart/Flutter codebase targeting **web, mobile (iOS/Android), and desktop
> (Windows/macOS)**, **offline-first** with **encrypted multi-device cloud sync**.
> It operationalizes the architecture ([03](03-architecture.md)), data model
> ([04](04-data-model.md)), OCR pipeline ([05](05-ocr-document-processing.md)),
> security model ([09](09-security-privacy.md)), and roadmap
> ([08](08-implementation-roadmap.md)) into concrete steps, code skeletons,
> configuration, and acceptance gates. Where this document and a spec doc disagree on
> detail, the spec doc owns *what*, this doc owns *how*.

---

## 0. How to use this document

- **Building from zero?** Read §1–§6 in order, then execute §13 (milestones) sprint by sprint.
- **Setting up a machine?** §2 (toolchain) and §3 (repo bootstrap).
- **Working a layer?** Jump to §5 (data/sync), §6 (auth/crypto), §7 (OCR), §8 (state/nav), §9 (design system), §10 (analytics).
- Every requirement ID (FR-*, NFR-*) referenced here traces back to
  [02-functional-requirements.md](02-functional-requirements.md).

---

## 1. Solution at a glance

| Layer | Responsibility | Key tech |
|-------|----------------|----------|
| Presentation | Screens, widgets, ViewModels | Flutter, Material 3, Riverpod, go_router |
| Application | Use-cases, service interfaces (ports) | Pure Dart |
| Domain | Entities, value objects (`Money`), rules | Pure Dart, `decimal`, `freezed` |
| Data — local | Working store, reactive queries, migrations | Drift over SQLite (encrypted) |
| Data — remote | Cloud persistence, auth, file storage | Supabase (Postgres, Auth, Storage, RLS) |
| Data — sync | Bidirectional offline-first sync | PowerSync |
| Data — OCR/docs | Scan → structured draft | platform-adaptive OCR, PDF, image |

**Golden rules**

1. **Local Drift DB is the single working source of truth on each device.** The UI only
   ever reads/writes the local DB; sync runs underneath. The app is fully usable offline.
2. **Domain depends on nothing.** Application defines interfaces; Data implements them;
   Presentation consumes them via Riverpod. No layer skips downward.
3. **Money is never a `double`.** `Decimal` everywhere; banker's rounding only at
   persistence/display boundaries.
4. **Tokens, not literals.** No widget hard-codes a color, size, or font (see [12](12-design-system-and-ux.md)).

---

## 2. Toolchain & prerequisites

| Tool | Baseline | Notes |
|------|----------|-------|
| Flutter SDK | latest **stable** channel | `flutter --version`; pin in `.fvmrc` via **FVM** for team consistency |
| Dart | bundled with Flutter (3.x) | |
| FVM | latest | per-repo Flutter version pinning |
| Melos | latest | monorepo task runner (optional but recommended) |
| Xcode | latest | iOS + macOS builds, signing, notarization (macOS host required) |
| Android Studio / SDK | latest | Android builds, emulators |
| Visual Studio (Desktop C++ workload) | 2022+ | required by Flutter **Windows** builds |
| CocoaPods | latest | iOS/macOS plugins |
| Supabase CLI | latest | local stack, migrations, edge functions, types |
| Node.js | LTS | Supabase CLI / Tesseract.js tooling / web |
| PowerSync CLI/SDK | latest | sync rules, local dev |

Bootstrap a dev machine:

```bash
dart pub global activate fvm
fvm install stable && fvm use stable
dart pub global activate melos
npm i -g supabase
flutter doctor        # resolve every platform you intend to build
```

`flutter doctor` must be green for the platforms a given developer targets (a
Windows dev need not have Xcode; CI covers the full matrix — §12).

---

## 3. Repository bootstrap

Melos monorepo, feature-first app package (see [03 §3](03-architecture.md)):

```
ledgerly/
├─ melos.yaml
├─ pubspec.yaml                 # melos workspace root
├─ .fvmrc
├─ app/                         # the Flutter application
│  ├─ pubspec.yaml
│  ├─ lib/
│  │  ├─ main.dart
│  │  └─ src/{core,domain,application,data,features}/...
│  ├─ android/ ios/ macos/ windows/ web/   # platform runners
│  └─ test/  integration_test/
├─ packages/
│  ├─ design_system/            # tokens, ThemeExtensions, shared widgets (widgetbook host)
│  └─ ledgerly_domain/          # (optional) extracted pure-Dart domain
├─ supabase/                    # migrations, RLS policies, edge functions, seed
│  ├─ migrations/
│  └─ functions/
└─ docs/
```

```bash
flutter create --org com.ledgerly --platforms=android,ios,web,windows,macos app
melos bootstrap        # pub get across all packages
```

`melos.yaml` scripts (run across packages): `analyze`, `test`, `build_runner`,
`format`, `gen-l10n`.

### 3.1 Dependency baseline (`app/pubspec.yaml`)

Pin to latest stable at project start; re-audit with `flutter pub outdated` each phase
(NFR-09). Representative set:

```yaml
dependencies:
  flutter: { sdk: flutter }
  flutter_localizations: { sdk: flutter }
  # State / DI / navigation
  flutter_riverpod: ^2
  riverpod_annotation: ^2
  go_router: ^14
  # Local DB
  drift: ^2
  sqlite3_flutter_libs: ^0
  sqlcipher_flutter_libs: ^0       # encrypted SQLite on native
  path_provider: ^2
  # Cloud + sync
  supabase_flutter: ^2
  powersync: ^1
  # Auth / crypto / secure storage
  flutter_secure_storage: ^9
  local_auth: ^2
  cryptography: ^2                 # AES-GCM, Argon2id, HKDF
  # Models / money / utils
  freezed_annotation: ^2
  json_annotation: ^4
  decimal: ^3
  intl: ^0
  # OCR / documents
  google_mlkit_text_recognition: ^0   # mobile (Android; iOS fallback)
  google_mlkit_document_scanner: ^0   # mobile doc capture
  image: ^4
  opencv_dart: ^1                      # FFI preprocessing (desktop/mobile)
  syncfusion_flutter_pdf: ^26          # PDF text extraction
  pdfrx: ^1                            # PDF rasterization
  file_picker: ^8
  image_picker: ^1
  camera: ^0
  # Charts / export
  fl_chart: ^0
  syncfusion_flutter_charts: ^26
  syncfusion_flutter_treemap: ^26
  printing: ^5                         # PDF report export
  pdf: ^3
  # Misc
  logger: ^2
dev_dependencies:
  build_runner: ^2
  drift_dev: ^2
  freezed: ^2
  json_serializable: ^6
  riverpod_generator: ^2
  custom_lint: ^0
  riverpod_lint: ^2
  mocktail: ^1
  alchemist: ^0                        # golden tests
  integration_test: { sdk: flutter }
  patrol: ^3                           # optional E2E
  widgetbook: ^3
```

> **Web caveat:** ML Kit / OpenCV-FFI / Tesseract-FFI are native-only. The OCR layer is
> behind an interface (§7) with a **Tesseract.js / TextDetector** web implementation and
> **conditional imports** so the web bundle never references native plugins.

### 3.2 Code generation

`drift_dev`, `freezed`, `json_serializable`, and `riverpod_generator` are all
build_runner based:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

Generated files (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`) are committed or
generated in CI before analyze/test (decide once; recommend **generated in CI**, not
committed, to avoid churn — gate `analyze`/`test` behind a `build_runner build` step).

---

## 4. Domain & application layers (pure Dart)

### 4.1 Money value object (ADR-005)

```dart
@immutable
class Money {
  final Decimal amount;
  final String currencyCode;       // ISO 4217
  const Money(this.amount, this.currencyCode);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amount + other.amount, currencyCode);
  }
  // banker's rounding applied ONLY at persistence/display boundaries:
  Decimal roundedTo(int digits) =>
      amount.round(scale: digits); // ToEven via decimal package config
  void _assertSameCurrency(Money o) {
    if (o.currencyCode != currencyCode) {
      throw CurrencyMismatchError(currencyCode, o.currencyCode);
    }
  }
}
```

Entities (`Transaction`, `LineItem`, `Category`, `Account`, `Merchant`, …) are
`freezed` immutable classes in `domain/`. Invariant `Σ LineItem.lineAmount ==
Transaction.totalAmount` (within rounding tolerance) is enforced in a domain rule and
surfaced by the LineItemEditor (FR-CAP-05).

### 4.2 Service ports (`application/`)

Abstract classes only — implementations live in `data/`:

```dart
abstract class TransactionService { /* CRUD, reconcile, soft-delete */ }
abstract class ScanService { Stream<ScanProgress> scan(ScanInput input); }
abstract class OcrEngine { Future<OcrResult> recognize(ImageData img, OcrOptions o); }
abstract class DocumentParser { DocumentType get type; DocumentDraft parse(OcrResult r, ParseContext c); }
abstract class CategorizationService { /* rules, merchant memory, suggest */ }
abstract class CurrencyService { /* base conversion, historical rates */ }
abstract class AnalyticsService { /* aggregations for charts/dashboard */ }
abstract class BudgetService { }
abstract class BackupService { }
abstract class ImportExportService { }
abstract class AttachmentStore { /* encrypted put/get, Storage-backed */ }
abstract class SyncService { /* connect, status stream, force sync */ }
abstract class AuthService { /* sign up/in/out, session, deletion */ }
abstract class AppLockService { /* unlock, auto-lock, biometric */ }
```

Each port is bound to a concrete impl by a Riverpod provider at the composition root
(§8.2).

---

## 5. Data layer — local DB, cloud, and sync

### 5.1 Drift local database (encrypted)

- Tables in `data/local/tables/` mirror [04](04-data-model.md). `TypeConverter`s:
  `Decimal` ⇄ TEXT, enums ⇄ TEXT, `DateTime` stored UTC ISO-8601.
- Every synced table carries the sync columns: `id` (UUID TEXT, PK), `userId`,
  `updatedAt` (UTC), `deleted` (bool tombstone), `opId`/version.
- Open with encryption on native:

```dart
QueryExecutor openEncrypted(String dbPath, Uint8List key) {
  return NativeDatabase.createInBackground(
    File(dbPath),
    setup: (raw) {
      raw.execute("PRAGMA key = \"x'${hex(key)}'\";"); // SQLCipher
      raw.execute('PRAGMA foreign_keys = ON;');
      raw.execute('PRAGMA journal_mode = WAL;');
    },
  );
}
```

- **Web:** Drift **WASM** worker over **OPFS** (origin-private file system). SQLCipher
  in WASM is heavier; on web the DB file lives in OPFS and sensitive blobs/payloads are
  additionally **client-side AES-GCM** encrypted (key in a non-extractable WebCrypto
  `CryptoKey`, see §6.4). Document this asymmetry honestly ([09](09-security-privacy.md)).
- DAOs expose **reactive `Stream` queries**; ViewModels watch them so the UI updates on
  any local write (including writes applied by the sync engine).

### 5.2 Migrations

- Drift `MigrationStrategy` with explicit `from→to` steps; `schemaVersion` bumped per
  change. A **pre-migration local snapshot** (copy the DB file) is taken before
  `onUpgrade` runs (NFR-05). Drift `schema dump` + migration tests guard every step.

### 5.3 Cloud schema (Supabase / Postgres)

- Mirror each synced entity as a Postgres table under a `public` (or `ledgerly`) schema,
  every row stamped with `user_id uuid not null default auth.uid()`, `updated_at`,
  `deleted`.
- **Row-Level Security** ON for every table:

```sql
alter table transactions enable row level security;
create policy "owner_rw" on transactions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
```

- Migrations live in `supabase/migrations/` (versioned SQL); apply via `supabase db
  push` (local) / CI. Generate Dart-friendly types if needed via the Supabase CLI.
- **Attachments** go to a Supabase **Storage** bucket (`attachments/{user_id}/…`),
  storing **client-side-encrypted** blobs (ciphertext only). Storage RLS restricts each
  path to its owner. DB holds attachment metadata + OCR text (also encrypted on web).

### 5.4 Sync engine (PowerSync — ADR-010)

- PowerSync connects the local SQLite (the same DB Drift reads, via the PowerSync
  SQLite adapter) to Supabase Postgres using **sync rules** that stream only the
  authenticated user's rows:

```yaml
# powersync sync rules (per-user bucket)
bucket_definitions:
  user_data:
    parameters: select request.user_id() as user_id
    data:
      - select * from transactions where user_id = bucket.user_id
      - select * from line_items   where user_id = bucket.user_id
      # …all synced tables
```

- **Upload:** local writes are queued and uploaded via a `PowerSyncBackendConnector`
  that authenticates with the Supabase session JWT and applies CRUD to Postgres.
- **Conflict resolution:** per-row **last-write-wins** on `updated_at`; deletes are
  tombstones (`deleted = true`) so they propagate, with a server-side/edge purge job
  after the retention window. Children (`LineItem`) are keyed to their parent and
  resolved with it.
- **Offline:** all reads/writes hit local SQLite; PowerSync flushes the upload queue and
  pulls deltas on reconnect (FR-SYNC). A `SyncService` exposes a status stream
  (connected / syncing / offline / error) for the UI indicator.
- **Alternatives considered** (ADR-010): a custom last-write-wins sync over Supabase
  Realtime + a change-log table, or Supabase's own client with a hand-rolled queue.
  PowerSync is chosen for purpose-built offline-first correctness; keep the
  `SyncService` interface so the engine is swappable.

---

## 6. Auth, encryption & key management (ADR-012, FR-AUTH, FR-SEC)

### 6.1 Authentication

- **Supabase Auth**: email+password, OAuth (Apple/Google), magic link. `AuthService`
  wraps it. Session JWT + refresh token persisted via `flutter_secure_storage`
  (Keychain/Keystore/DPAPI/libsecret; web uses encrypted storage). Optional MFA.
- Account flows: sign up, sign in, sign out, password reset, **data export**, **account
  deletion** (right to erasure — [09](09-security-privacy.md)).

### 6.2 Local app lock (FR-SEC-02/03/05)

- `AppLockService`: after sign-in, the app can be locked behind a **biometric/local
  unlock** via `local_auth` (Face ID / Touch ID / Android biometrics / Windows Hello;
  web falls back to passphrase). **Auto-lock** on idle timeout drops the in-memory key.

### 6.3 Encryption model (ADR-012)

- **At rest on device:** SQLCipher key (§5.1) on native; OPFS + WebCrypto on web.
- **In transit:** TLS to Supabase.
- **At rest in cloud:** Postgres + Storage encryption; tenant isolation via RLS.
- **Client-side (E2E) for sensitive data:** attachments and selected sensitive payloads
  are encrypted with **AES-256-GCM** before leaving the device; the cloud stores
  ciphertext. Analytics still work because they run on the **decrypted local** DB.

### 6.4 Key derivation & multi-device (ADR-012)

```
passphrase ──Argon2id(salt, params)──▶ master key (MK)
MK ──wraps──▶ data encryption key (DEK)   (random, per-account)
DEK encrypts: SQLCipher key material + attachment keys
Recovery phrase (BIP39-style) ──▶ alternate wrap of DEK  (account recovery)
```

- On a new device: sign in → fetch wrapped DEK → unwrap with passphrase (or recovery
  phrase) → derive/open local encryption. The DEK never leaves the device in plaintext;
  only wrapped forms are stored server-side.
- **Forgotten passphrase** is recoverable via the **recovery phrase**; losing **both**
  is unrecoverable by design — surfaced clearly at onboarding.
- Argon2id and AES-GCM via the `cryptography` package; secrets held in pinned/secure
  buffers and cleared on lock where the runtime allows.

---

## 7. OCR & document pipeline (platform-adaptive — ADR-003)

### 7.1 Engine selection

`OcrEngine` is resolved per platform via conditional imports / a factory:

| Platform | Implementation |
|----------|----------------|
| Android | `google_mlkit_text_recognition` (on-device) |
| iOS & macOS | Apple **Vision** (`VNRecognizeTextRequest`) via a platform-channel plugin (ML Kit fallback on iOS) |
| Windows / Linux | **Tesseract** via FFI, bundled `ces`+`eng` tessdata |
| Web | **Tesseract.js** (WASM) via JS interop, or browser `TextDetector` |
| (optional) | opt-in cloud fallback via a Supabase **Edge Function** |

```dart
// ocr/ocr_engine_factory.dart  (conditional import keeps native plugins out of web)
import 'ocr_engine_stub.dart'
    if (dart.library.io) 'ocr_engine_native.dart'
    if (dart.library.js_interop) 'ocr_engine_web.dart';
```

### 7.2 Pipeline (runs in an isolate)

`Ingest → Preprocess (image / opencv_dart) → OCR → Classify → Parse (header + line
items, reconcile to total) → Suggest categories → Review screen → Persist + attach`.
Heavy steps run via `Isolate.run`/`compute` so the UI stays responsive (NFR-01).
PDF: detect text layer (`syncfusion_flutter_pdf`) vs rasterize (`pdfrx`) → OCR.

- `ScanService.scan()` returns a `Stream<ScanProgress>` (cancelable) ending in a
  non-persisted `DocumentDraft` the review screen binds to.
- On confirm: write `Transaction`+`LineItem`s locally (sync picks them up), encrypt the
  original document, upload to Storage via `AttachmentStore`, persist `OcrText`.
- Accuracy harness: a fixture corpus (CZ+EN) with ground-truth JSON; parsers unit-tested
  against `OcrResult` fixtures (deterministic, no image needed) — see
  [05 §7](05-ocr-document-processing.md).

---

## 8. Presentation: state, navigation, structure

### 8.1 MVVM with Riverpod (ADR-011)

- One **ViewModel per screen** as a `Notifier`/`AsyncNotifier` exposing immutable
  (`freezed`) UI state. Views are `ConsumerWidget`s that `ref.watch` the ViewModel and
  dispatch intents to its methods. ViewModels depend only on **application** ports.

```dart
@riverpod
class TransactionsViewModel extends _$TransactionsViewModel {
  @override
  Stream<TransactionsState> build() =>
      ref.watch(transactionServiceProvider).watchFiltered(ref.watch(filterProvider));
  Future<void> delete(String id) =>
      ref.read(transactionServiceProvider).softDelete(id);
}
```

### 8.2 Dependency injection (composition root)

- Providers bind interfaces → implementations in one place (`core/di/`):

```dart
@riverpod
TransactionService transactionService(Ref ref) =>
    DriftTransactionService(ref.watch(appDatabaseProvider));
@riverpod
OcrEngine ocrEngine(Ref ref) => createOcrEngine();      // platform factory
@riverpod
SyncService syncService(Ref ref) => PowerSyncService(...);
```

Swapping an implementation (e.g. the sync engine) is a one-line provider change.
Tests override providers with `mocktail` fakes.

### 8.3 Navigation (go_router)

- URL-addressable routes (web deep links): `/dashboard`, `/transactions`,
  `/transactions/:id`, `/scan`, `/scan/review`, `/categories`, `/analytics`,
  `/budgets`, `/accounts`, `/settings`. A **redirect guard** sends unauthenticated /
  locked sessions to `/auth` or `/lock`.
- **Responsive shell** (see [06](06-ux-ui-spec.md)): `NavigationBar` (mobile bottom),
  `NavigationRail`/extended drawer (tablet/desktop/web), driven by `LayoutBuilder`
  breakpoints from the design system ([12](12-design-system-and-ux.md)).

---

## 9. Design system implementation ([12](12-design-system-and-ux.md))

- `packages/design_system`: tokens as Flutter **`ThemeExtension`**s (color, space,
  radius, elevation, type, motion), built on `ColorScheme.fromSeed` with light / dark /
  high-contrast and dynamic color on Android 12+.
- Shared widgets: `MoneyText`, `AmountInput`, `CategoryPicker`, `CategoryChip`,
  `TransactionRow`/`SplitExpander`, `LineItemEditor`, `KpiCard`, `ChartPanel`,
  `FilterBar`, `DateRangePicker`, `ConfidenceField`, `EmptyState`,
  `SyncStatusIndicator`, `BiometricUnlock`. Tokens only; full `Semantics`.
- **fl_chart** and Syncfusion charts are themed from the **same tokens** (category color
  is single source of truth). A **widgetbook** "kitchen-sink" hosts every component in
  every state across themes/densities/locales — the visual-regression surface (golden
  tests via `alchemist`).

---

## 10. Analytics implementation ([07](07-analytics-visualizations.md), [11](11-analysis-and-visualization-deep-dive.md))

- Aggregations are **SQL `GROUP BY`/sum queries in the local Drift DB** over indexed
  columns — they run **fully offline** because the working data is local. `Stream`
  queries push pre-binned series to charts; no row-by-row materialization.
- A single `AnalyticsService` implements every metric once so all screens reconcile.
- Optional **monthly rollup** Drift table for instant dashboards on large datasets,
  invalidated on data change. Filter changes debounce (~150 ms) and cancel superseded
  queries.
- Chart types: native (line/bar/pie/area) from fl_chart; treemap/heatmap via Syncfusion;
  waterfall/calendar-heatmap via `CustomPainter`. "Show as table" + PNG/CSV/PDF export
  (`printing`/`pdf`) for accessibility and reporting.

---

## 11. Cross-cutting: localization, logging, error handling

- **l10n**: `intl` ARB files (`lib/src/core/l10n/`), `flutter gen-l10n`; EN + CS;
  locale-aware `NumberFormat`/`DateFormat`. No hard-coded user-facing strings.
- **Logging**: `logger` to console (debug) and a rolling local file (release) via
  `path_provider`; **no network sink** by default. **Opt-in** Sentry for crash
  reporting (NFR-04) — never sends financial data.
- **Errors**: typed failures (`freezed` sealed unions) bubble to ViewModels → calm,
  actionable UI; `FlutterError.onError` + zone guard capture uncaught errors locally.

---

## 12. CI/CD & quality gates

GitHub Actions, multi-platform matrix:

```yaml
jobs:
  static:                       # ubuntu
    steps: [checkout, fvm/setup, melos bootstrap,
            "dart run build_runner build --delete-conflicting-outputs",
            "dart analyze", "dart format --set-exit-if-changed .",
            "flutter test --coverage"]   # unit + widget + golden
  build_android:  { runs-on: ubuntu-latest }   # flutter build appbundle
  build_ios:      { runs-on: macos-latest }     # flutter build ipa (signing)
  build_macos:    { runs-on: macos-latest }     # build + notarize (Phase 4)
  build_windows:  { runs-on: windows-latest }   # flutter build windows + msix
  build_web:      { runs-on: ubuntu-latest }    # flutter build web (PWA)
  integration:    { runs-on: macos-latest }     # integration_test on a device/sim
```

**Quality gates (NFR-09):** `dart analyze` clean (custom_lint + riverpod_lint),
formatting enforced, ≥ **70% coverage on domain/application**, golden tests for the
design system, migration tests green, `flutter pub outdated`/audit reviewed each phase.
Store deploys (Phase 4) via **Fastlane**/**Codemagic** (Play, App Store, notarized mac,
Windows installer) and static hosting + service worker for the web PWA.

---

## 13. Milestones, sequencing & acceptance gates

Each phase ends with a runnable build on **all platforms** and acceptance criteria that
trace to requirement IDs (mirrors [08](08-implementation-roadmap.md)).

### Phase 0 — Foundation (sync-capable skeleton)
**Build:** melos repo, FVM, Riverpod + go_router shell, encrypted Drift DB, Supabase
project + Auth, PowerSync wired, multi-platform CI, design-system token base + widgetbook.
**Vertical slice:** sign in → create a `Transaction` on device A → it appears on device B
(and web) within seconds; works offline and converges on reconnect.
**Exit:** app launches on iOS/Android/Web/Windows/macOS; unlock works; one transaction
round-trips through local DB + cloud + a second device. Unit tests green in CI.

### Phase 1 — MVP core (capture + categorize + analytics + sync)
**Build:** full schema; manual capture with **multi-category line-item editor** +
reconciliation + transfers (FR-CAP); categories/subcategories + tags (FR-CAT-01..04,08);
multi-currency + historical rates + base-amount caching (FR-CUR); accounts/balances
(FR-ACC); dashboard + spend-by-category + over-time + income-vs-expense + global filters
+ drill-down (FR-ANL-01..05,10); CSV import/export + encrypted local export & restore
(FR-DAT); offline-first sync solid on all platforms (FR-SYNC); light/dark + responsive nav.
**Exit:** a user runs their whole finances across phone + laptop + web — multi-category,
multi-currency entries; dashboard + 3 core charts with filters/drill-down; backup/restore;
CSV in/out; edits on one device appear on the others. NFR-01 met on 10k seeded tx.

### Phase 2 — Scanning (platform-adaptive OCR)
**Build:** `OcrEngine` impls (ML Kit / Apple Vision / Tesseract / Tesseract.js); ingest
(image, camera/doc-scanner, PDF text + rasterize); opencv preprocessing in isolates;
classifier + per-type parsers + reconciliation + confidence; **review screen** (adaptive
split/stacked) with confidence highlighting; encrypted attachments synced to Storage +
OCR-text search; auto-categorization rules + merchant memory (FR-CAT-05/06).
**Exit:** scan a printed receipt → review → save itemized, multi-category, with attached
encrypted document syncing across devices, meeting [05 §1](05-ocr-document-processing.md)
accuracy targets. Works offline.

### Phase 3 — Deeper analysis & budgets
**Build:** budgets + actual-vs-budget + alerts (FR-BUD); advanced charts (treemap,
calendar heatmap, waterfall, MoM/YoY, top merchants); recurring detection + recurring
templates (FR-CAP-07); **PDF report export** (FR-DAT-06) via `printing`/`pdf`; optional
online rate fetch (FR-CUR-05); per-merchant OCR templates (FR-SCAN-10).
**Exit:** budgets tracked with alerts; all advanced charts live with drill-down; PDF
report exports for a chosen period.

### Phase 4 — v1.0 polish & release
**Build:** store releases (Play / App Store / **notarized macOS** / Windows installer /
**Web PWA**); onboarding (account + encryption/recovery-phrase setup); accessibility pass
(Semantics, screen readers, contrast, text scaling); EN/CS localization; biometric unlock
+ auto-lock; **E2E-encryption hardening**; performance hardening to NFR-01/02 on 100k tx +
rollup cache; opt-in crash reporting; privacy policy + data-export/deletion flows.
**Exit:** signed/notarized builds on all five targets; onboarding; AA accessibility on
core flows; CS/EN; all NFRs met; GDPR flows (export/erasure) working.

### Cross-phase definition of done (every feature)
- Correct layer; interface in `application`, impl in `data`; domain dependency-free.
- Unit tests for domain/application; widget + golden tests for UI; ≥ 70% core coverage.
- `dart analyze` clean (custom_lint/riverpod_lint); `dart format` enforced.
- Works **offline** and **syncs** correctly across two devices.
- Requirement IDs referenced in the PR; docs updated if behavior changed.
- Verified light + dark, mobile + desktop, EN + CS, at ≥150% text scale.

---

## 14. Key risks for the build (see [10](10-risks-and-decisions.md))

| Risk | Mitigation in this plan |
|------|-------------------------|
| Sync-conflict correctness | LWW on `updatedAt` + tombstones; child-keyed resolution; sync tests with simulated offline edits on two clients. |
| Web encryption / OPFS maturity | Drift WASM + OPFS + client-side AES-GCM; documented asymmetry; fall back to in-memory + cloud where OPFS unavailable. |
| Multi-platform OCR variance | One `OcrEngine` interface; per-platform impls; accuracy harness per engine; mandatory human review. |
| Store review / notarization friction | Phase 4 budget for signing, notarization, privacy declarations; Fastlane automation. |
| Key-loss vs cloud-recovery tension | Recovery phrase enables passphrase recovery; lose-both = unrecoverable, surfaced at onboarding. |
| RLS misconfiguration leaking data | RLS on every table + policy tests in CI; PowerSync per-user sync rules; least-privilege keys. |
| Cloud cost / vendor lock-in | Interfaces (`SyncService`, `AttachmentStore`, `AuthService`) keep Supabase/PowerSync swappable; monitor usage. |

---

## 15. First-week checklist (concrete kickoff)

1. `flutter create` the app with all five platforms; `melos bootstrap`; commit.
2. Stand up a Supabase project (prefer **EU region** for residency); enable Auth; create
   the first migration (transactions + RLS) in `supabase/migrations/`.
3. Wire Drift encrypted DB + the PowerSync SQLite adapter; implement
   `PowerSyncBackendConnector` against the Supabase session.
4. Build the Riverpod composition root + go_router responsive shell + auth/lock guards.
5. Lay down the design-system token package + widgetbook + first golden test.
6. Ship the **Phase 0 vertical slice** and the multi-platform CI matrix.
7. Demonstrate a transaction syncing phone ⇄ web ⇄ desktop, online and after reconnect.
