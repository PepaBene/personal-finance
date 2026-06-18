# Ledgerly

> Offline-first, encrypted, cloud-synced personal-finance app — one Flutter
> codebase for **iOS, Android, Web (PWA), Windows, and macOS**.

Product & engineering specs live in [`docs/`](docs/00-README.md). This README
covers the **Phase 0 foundation** scaffold (see
[docs/08 — Roadmap](docs/08-implementation-roadmap.md) and
[docs/13 — Technical Plan](docs/13-technical-implementation-plan.md)).

## What Phase 0 delivers

A buildable, layered, multi-platform app with encrypted local storage, a wired
cloud backend, and a vertical slice (create & list a Transaction) through every
layer:

- **Melos monorepo**: `app/` (the Flutter app) + `packages/design_system`
  (tokens, theme, shared widgets) + `supabase/` (cloud schema, RLS, sync rules).
- **Clean layering** (docs/03 §3): `domain` (pure Dart) ← `application` (ports)
  ← `data` (Drift / Supabase / PowerSync adapters) ← `features` (Riverpod
  MVVM + Material 3). Wired at one composition root (`app/lib/src/core/di`).
- **Encrypted local DB**: Drift over SQLite, SQLCipher on native / WASM+OPFS on
  web, opened with an Argon2id-derived key (FR-SEC-01/02).
- **Cloud + sync**: Supabase (Postgres + Auth + RLS) mirrored schema and
  PowerSync per-user sync rules (FR-AUTH, FR-SYNC, FR-SEC-06).
- **Adaptive shell**: go_router with auth + lock guards; `NavigationBar` ↔
  `NavigationRail`; honest sync-status indicator.
- **CI**: GitHub Actions matrix — analyze, format, codegen, tests, and
  Web/Android/macOS builds.

## Layout

```
.
├─ app/                      # Flutter application (lib/src/{core,domain,application,data,features})
├─ packages/design_system/   # ThemeExtension tokens, theme, shared widgets
├─ supabase/                 # migrations (schema + RLS) and PowerSync sync rules
├─ .github/workflows/ci.yaml # multi-platform CI
├─ melos.yaml                # workspace task runner
└─ docs/                     # product & engineering specs
```

## Prerequisites

- Flutter (stable channel) + Dart 3.x — pin with [FVM](https://fvm.app)
  (`.fvmrc` targets `stable`).
- `dart pub global activate melos`
- For the backend: a Supabase project + PowerSync instance (see
  [`supabase/README.md`](supabase/README.md)).

## Build & run

```bash
dart pub global activate melos
melos bootstrap                 # pub get across all packages

# One-time: materialize platform runners (not committed; they are large and
# platform-specific). CI does this automatically.
cd app && flutter create --platforms=android,ios,web,windows,macos \
  --org com.ledgerly --project-name ledgerly_app . && cd ..

melos run generate              # build_runner: drift/freezed/riverpod
melos run gen-l10n              # localization (EN + CS)

# Run with the backend configured (no secrets in source — docs/09 §8):
cd app && flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=POWERSYNC_URL=https://<instance>.powersync.journeyapps.com
```

## Quality gates

```bash
melos run analyze   # dart analyze (strict; custom_lint + riverpod_lint)
melos run format    # dart format --set-exit-if-changed
melos run test      # unit + widget tests
```

## Notes for reviewers

- **Generated code is not committed** (docs/13 §3.2): `*.g.dart`,
  `*.freezed.dart`, `*.drift.dart`, and the l10n output are produced by
  `melos run generate` / `gen-l10n` before analyze/test. Until you run codegen
  locally, references to those parts will show as unresolved.
- **Platform runner folders** (`android/`, `ios/`, `web/`, …) are generated via
  `flutter create`, not committed, so the repo stays focused on source.
- **Drift runs on top of the PowerSync database** (`SqliteAsyncDriftConnection`
  in `core/di/providers.dart`): one shared SQLite store, encrypted on native via
  a SQLCipher `PowerSyncOpenFactory`. PowerSync owns the synced-table DDL, so the
  Drift migration is a no-op for them (`data/local/app_database.dart`).
- The live **two-device** integration assertion is the remaining Phase 0 seam
  (`integration_test/`), pending a provisioned test backend. The web SQLCipher
  asymmetry is documented in `ledgerly_powersync_web.dart` (docs/09 §2).

## Status

**Phase 0 complete** (foundation, encrypted Drift⇄PowerSync, auth + sync
coordinator). **Phase 1 in progress** — the MVP data foundation has landed:

- Full Drift schema (transactions, line items, categories, accounts, merchants,
  tags, currencies, exchange rates, settings) with sync columns, mirrored in
  PowerSync + Postgres (RLS) + sync rules (docs/04).
- Domain entities + the Σ-lines reconciliation rule (FR-CAP-05); line-item-aware
  transactional persistence with tombstone-cascade.
- Category, Account (with balances), and Currency (base + historical-rate
  conversion) services; idempotent, deterministic-id seeding of default
  categories, currencies, a starter account, and the base currency.

Next in Phase 1: the capture UI (multi-category **line-item editor**, accounts &
transfers, currency picker) and **core analytics** (dashboard + spend-by-
category / over-time / income-vs-expense with global filters and drill-down),
then CSV import/export (docs/08 Phase 1 workstreams 2–8).
