# Technical Architecture

**Version:** 0.1 · **Date:** 2026-06-09

---

## 1. Architectural overview

A single-process, layered **MVVM desktop application** on **.NET 10 (LTS)**. All logic, storage, OCR, and analytics run **in-process and offline**. There is no server.

> **Version policy:** target the current LTS and latest stable libraries (verified 2026-06-09). Pin exact versions in `Directory.Packages.props` (central package management) and review with `dotnet list package --outdated` each phase. See [§2.1](#21-pinned-versions-verified-2026-06-09).

```
┌──────────────────────────────────────────────────────────────┐
│  Presentation (WinUI 3, MVVM)                                 │
│   Views (XAML)  ──bind──  ViewModels  ──use──  App Services   │
├──────────────────────────────────────────────────────────────┤
│  Application layer (use-cases / services)                     │
│   TransactionService · ScanService · CategorizationService    │
│   AnalyticsService · CurrencyService · BackupService          │
├──────────────────────────────────────────────────────────────┤
│  Domain (entities, value objects, rules)                      │
│   Transaction · LineItem · Category · Money · ExchangeRate …  │
├──────────────────────────────────────────────────────────────┤
│  Infrastructure                                               │
│   EF Core + SQLite/SQLCipher repo · OCR engine adapters ·     │
│   PDF/Image processing · File store · Importers/Exporters     │
└──────────────────────────────────────────────────────────────┘
```

**Design principles**

- **Local-first & offline-by-default** — no feature depends on the network (one optional, explicit rate-fetch aside).
- **Separation of concerns** — UI never touches the database; it goes through application services. Domain has no framework dependencies.
- **Dependency injection** everywhere (`Microsoft.Extensions.DependencyInjection`), so OCR engines, repositories, and rate providers are swappable behind interfaces.
- **Testability** — domain + application layers are pure C# and unit-tested without a UI.
- **Async I/O** — OCR, PDF rendering, and DB queries run off the UI thread.

## 2. Technology stack

| Concern | Choice | Notes |
|---------|--------|-------|
| Language / runtime | **C# 14 / .NET 10 (LTS)** | Released Nov 2025, supported to Nov 2028. (.NET 8/9 both EOL Nov 2026 — do not target them.) Native AOT-capable for parts if needed. |
| UI framework | **WinUI 3 (Windows App SDK 2.0)** | Modern Fluent UI, native Windows look; WinUI is now on a Long-Term Servicing Channel (Build 2026). **Fallback: WPF** (see ADR-001). |
| MVVM toolkit | **CommunityToolkit.Mvvm 8.4.2+** | Source-generated `ObservableObject`, `RelayCommand`, messaging. Pin **≥ 8.4.2** — 8.4.0 fails to build on default .NET 10 settings. |
| DI / hosting | **Microsoft.Extensions.Hosting / DependencyInjection 10.x** | App composition root, config, logging. |
| ORM | **Entity Framework Core 10** + **Microsoft.Data.Sqlite 10.x** | Migrations, LINQ queries; EF 10 adds complex types, JSON updates, Left/RightJoin, named filters, faster queries. |
| Database | **SQLite** with **SQLCipher** (`SQLitePCLRaw.bundle_e_sqlcipher`) | Encrypted at rest. |
| OCR (primary) | **Windows.Media.Ocr** (built into Windows) | Offline, no extra install, decent on printed text. |
| OCR (secondary) | **Tesseract** (`TesseractOCR`/`Tesseract` NuGet) | More languages / tunable; optional engine. |
| PDF (digital text) | **PdfPig** | Extract embedded text & positions from text PDFs. |
| PDF (scanned → image) | **Docnet.Core** or **PDFtoImage** | Rasterize pages for OCR when no text layer. |
| Image processing | **OpenCvSharp4** (or **ImageSharp**) | Deskew, threshold, crop, denoise before OCR. |
| Charts | **LiveChartsCore (LiveCharts2) 2.0.4+ (SkiaSharp)** | Cross-UI, animated; stable 2.0 line with a WinUI view package. Alt: **ScottPlot 5.x**. |
| Logging | **Serilog** (file sink, local only) | Rolling logs, no network sink. |
| Validation | **FluentValidation** | Input/domain validation. |
| Mapping | Manual or **Mapster** | DTO ↔ entity. |
| Tests | **xUnit** + **FluentAssertions** + **NSubstitute/Moq** | Unit/integration; **WinAppDriver/FlaUI** optional for UI. |
| Packaging | **MSIX** (Windows App SDK) | Signed installer + auto-update (v1.0). |
| Scanning device | **WIA** (Windows Image Acquisition) / `MediaCapture` (webcam) | Optional acquire-from-device path. |

> See [10-risks-and-decisions.md](10-risks-and-decisions.md) for ADRs justifying the major choices.

### 2.1 Pinned versions (verified 2026-06-09)

Use **central package management** (`Directory.Packages.props`) so every project shares one version source of truth. Target latest stable; re-check with `dotnet list package --outdated` and `--vulnerable` at the start of each phase.

| Package / SDK | Pinned baseline |
|---------------|-----------------|
| .NET SDK / runtime | **10.0.x (LTS)**, `LangVersion` = C# 14 |
| Windows App SDK | **2.0.x** (WinUI 3) |
| Visual Studio | **2026** (or `dotnet` CLI 10) |
| EF Core + Microsoft.Data.Sqlite | **10.0.x** |
| Microsoft.Extensions.* (Hosting/DI/Logging) | **10.0.x** |
| CommunityToolkit.Mvvm | **8.4.2+** (never 8.4.0 on .NET 10) |
| SQLitePCLRaw.bundle_e_sqlcipher | latest stable |
| LiveChartsCore.SkiaSharpView.WinUI | **2.0.4+** |
| Serilog (+ File sink) | latest stable |
| FluentValidation | latest stable |
| PdfPig / Docnet.Core / OpenCvSharp4 | latest stable |
| Tesseract (NuGet) + tessdata (ces, eng) | latest stable |
| xUnit / FluentAssertions / NSubstitute | latest stable |

> Rationale for the major bump from the original ".NET 8 / WASDK 1.5" draft: as of 2026-06 .NET 8 & 9 reach end-of-support in Nov 2026, while **.NET 10 is the current LTS to Nov 2028**, and **Windows App SDK 2.0** is the supported WinUI baseline. Tracked as ADR-008 in [10-risks-and-decisions.md](10-risks-and-decisions.md).

## 3. Solution structure

A multi-project .NET solution keeps layers honest (project references enforce direction):

```
Ledgerly.sln
├─ src/
│  ├─ Ledgerly.Domain/          # entities, value objects, domain rules (no deps)
│  ├─ Ledgerly.Application/     # services/use-cases, interfaces (ports), DTOs
│  ├─ Ledgerly.Infrastructure/  # EF Core, repos, OCR adapters, PDF/image, file store
│  │   ├─ Persistence/          # DbContext, configs, migrations, encryption
│  │   ├─ Ocr/                  # IOcrEngine impls (WindowsOcr, Tesseract)
│  │   ├─ DocumentParsing/      # classifiers + parsers (receipt/invoice/paycheck)
│  │   ├─ Currency/             # rate providers, conversion
│  │   └─ IO/                   # importers/exporters, backup
│  └─ Ledgerly.App/             # WinUI 3 app: Views, ViewModels, DI bootstrap
├─ tests/
│  ├─ Ledgerly.Domain.Tests/
│  ├─ Ledgerly.Application.Tests/
│  └─ Ledgerly.Infrastructure.Tests/
└─ docs/                        # these documents
```

**Reference direction:** App → Application → Domain; Infrastructure → Application/Domain. Domain references nothing. App composes Infrastructure only at the DI root.

## 4. Key application services (ports)

| Service | Responsibility |
|---------|----------------|
| `ITransactionService` | CRUD for transactions & line items, balance reconciliation, soft-delete. |
| `IScanService` | Orchestrates: ingest → preprocess → OCR → classify → parse → draft transaction. |
| `IOcrEngine` | Abstraction over OCR backends (Windows.Media.Ocr, Tesseract). |
| `IDocumentParser` | Per-doc-type extraction of header fields & line items from OCR result. |
| `ICategorizationService` | Default/auto category suggestion, rules engine, merchant memory. |
| `ICurrencyService` | Base-currency conversion using historical rates; rate storage; optional fetch. |
| `IAnalyticsService` | Aggregations for dashboards/charts (by category, period, merchant, budget). |
| `IBudgetService` | Budget CRUD and actual-vs-budget computation. |
| `IBackupService` | Encrypted backup/restore, integrity check. |
| `IImportExportService` | CSV import (mapping), CSV/PDF export. |
| `IFileStore` | Encrypted storage/retrieval of attached documents. |
| `IAppLock` | Master-password/KDF unlock, key lifetime, optional Windows Hello, auto-lock. |

Each is an interface in `Application`, implemented in `Infrastructure`, consumed by ViewModels.

## 5. Scan pipeline (high level)

```
File/Scanner ─▶ Ingest ─▶ Preprocess (deskew/threshold) ─▶ OCR (text+boxes)
            ─▶ Classify doc type ─▶ Parse (header + line items) ─▶ Suggest categories
            ─▶ Draft transaction ─▶ [Review screen / user edits] ─▶ Save + attach doc
```

Detailed design, parsing heuristics, and accuracy strategy in [05-ocr-document-processing.md](05-ocr-document-processing.md).

## 6. Threading & performance

- UI thread only renders & binds. All services are `async` and run work on the thread pool.
- OCR/PDF rasterization is CPU-heavy → run on background tasks with progress + cancellation.
- Analytics queries are pushed to SQL (EF `GroupBy`, aggregates) rather than materializing all rows; cache results per filter set.
- Large lists use **UI virtualization**; charts aggregate server-side (in-DB) before plotting.
- Indices on `Transaction(date)`, `Transaction(merchant_id)`, `LineItem(category_id)`, `LineItem(transaction_id)` (see [04](04-data-model.md)).

## 7. Configuration & storage locations

- App data root: `%LOCALAPPDATA%\Ledgerly\`
  - `ledgerly.db` (encrypted SQLite)
  - `attachments/` (encrypted document blobs, or stored as DB BLOBs — see ADR-004)
  - `logs/` (local Serilog files)
  - `backups/` (user may also choose external path, e.g. OneDrive folder for off-box copy)
- Settings: a `settings` table in the DB + non-sensitive prefs in a local JSON file.

## 8. Build, test, CI

- Local build via `dotnet build` (.NET 10 SDK) / Visual Studio 2026.
- CI (GitHub Actions, Windows runner): restore → build → unit tests → (optional) package MSIX.
- Quality gates: analyzers + nullable reference types **on**, warnings-as-errors in CI for core libs.

## 9. Open architectural questions

- **WinUI 3 vs WPF** for v1 — resolved provisionally as WinUI 3 with WPF fallback (ADR-001). Charting library availability is the deciding factor; LiveCharts2 supports both, de-risking the choice.
- **Attachment storage** — encrypted files on disk vs BLOBs in the encrypted DB (ADR-004).
- **OCR engine default** — Windows.Media.Ocr vs Tesseract as the shipped default (ADR-003).

These are tracked in [10-risks-and-decisions.md](10-risks-and-decisions.md) and resolved before the relevant phase begins.
