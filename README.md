# Ledgerly

A local-first, offline, **encrypted** Windows desktop app for personal expense
tracking — built on **.NET 10 / C# 14** with a **WinUI 3** front end. All data lives
only on the user's PC in an encrypted SQLite (SQLCipher) database; nothing leaves the
device. See [`docs/`](docs/00-README.md) for the full product, architecture, data,
security and UX specifications, and [`.claude/plans`](.claude/plans) for the
phased implementation plan.

## Status — Phase 0 (Foundation & scaffolding) ✅

Phase 0 (per [docs/08](docs/08-implementation-roadmap.md)) delivers a buildable,
layered, dependency-injected solution with encrypted storage, app unlock, logging,
CI, and one end-to-end vertical slice.

| Phase 0 task | Status |
|--------------|--------|
| 0.1 Layered solution + central package management + build props | ✅ |
| 0.2 DI/host composition root, Serilog (local file sink), settings store | ✅ |
| 0.3 Encrypted persistence (EF Core 10 + SQLite + **SQLCipher**), `foreign_keys` + WAL | ✅ |
| 0.4 App lock: master password → **KDF** → DB key (FR-SEC-01/02), re-key on change | ✅ |
| 0.5 Vertical slice: create & list a `Transaction` through all layers | ✅ |
| 0.6 CI (GitHub Actions, Windows): build + test | ✅ |

**Exit criteria met:** the app unlocks with a password, persists one **encrypted**
transaction and reopens it after restart; the database is unreadable without the key;
the wrong password is rejected; unit/integration tests are green in CI.

## Solution layout

```
Ledgerly.sln
├─ src/
│  ├─ Ledgerly.Domain/          # entities, Money value object (no framework deps)
│  ├─ Ledgerly.Application/     # service contracts (ports), DTOs
│  ├─ Ledgerly.Infrastructure/  # EF Core + SQLCipher, KDF/app-lock, settings, services
│  └─ Ledgerly.App/             # WinUI 3 desktop app (Windows-only)
└─ tests/
   ├─ Ledgerly.Domain.Tests/
   ├─ Ledgerly.Application.Tests/
   └─ Ledgerly.Infrastructure.Tests/   # encryption-at-rest, app-lock, persistence
```

Reference direction is enforced by project references: `App → Application → Domain`,
`Infrastructure → Application/Domain`, and `Domain` depends on nothing
([docs/03 §3](docs/03-architecture.md)).

## Build & test

Requires the **.NET 10 SDK**. The cross-platform core (Domain/Application/
Infrastructure + tests) builds and tests via a solution filter; the WinUI app is
Windows-only.

```bash
# Core (cross-platform layers + tests) — gated in CI
dotnet restore Ledgerly.Core.slnf
dotnet build   Ledgerly.Core.slnf -c Release
dotnet test    Ledgerly.Core.slnf -c Release

# WinUI desktop app (Windows + Windows App SDK only)
dotnet build src/Ledgerly.App/Ledgerly.App.csproj -c Release -p:Platform=x64
```

> The encryption tests exercise SQLCipher, whose native binaries ship for `win-x64`
> via `SQLitePCLRaw.bundle_e_sqlcipher`, so CI runs them on a Windows runner.

## Security design (Phase 0)

- **At rest:** the whole database is encrypted with **SQLCipher** (AES-256), keyed via
  `PRAGMA key` on every connection by `SqlCipherConnectionInterceptor`, which also sets
  `PRAGMA foreign_keys = ON` and `PRAGMA journal_mode = WAL`. Connection pooling is
  disabled so keying is always the first statement on a fresh handle.
- **Key derivation:** the master password is run through **PBKDF2-HMAC-SHA256**
  (600k iterations, per-install random salt) to derive a 256-bit key. The salt and KDF
  parameters live in a non-secret `security.json`; the **key itself is never written to
  disk** and is zeroed from memory on lock (docs/09 §3). Argon2id (the doc's preferred
  KDF) is tracked as open question #4 and can replace PBKDF2 behind the same config.
- **No recovery by design:** forgetting the master password makes the data
  unrecoverable. Password changes re-key the database with SQLCipher `PRAGMA rekey`.

## Documented Phase 0 decisions / deviations

- **Schema via `EnsureCreated()` (not an EF migration yet).** The roadmap calls for a
  "first migration," but generating EF migrations requires the .NET 10 + EF tooling on
  the build host, which the current cloud session lacks. Phase 0 therefore materializes
  its tiny schema with `EnsureCreated()`, and ships an `IDesignTimeDbContextFactory` so
  the **first real migration is generated in Phase 1** when the full data model lands
  and FR-DAT-07 (auto-migrations + pre-migration snapshot) is implemented.
- **WinUI app is built in a non-gating CI job.** It only builds on Windows with the
  Windows App SDK; the gating job is the cross-platform core + tests. The Windows App
  SDK package versions in `Directory.Packages.props` are a baseline to verify on a
  Windows dev machine before the Phase 1 UI work.
