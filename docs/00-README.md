# Personal Finance App — Documentation

> **Working title:** *Ledgerly* (provisional — rename freely)
> A cross-platform personal-finance app for recording, scanning, categorizing, and analyzing personal expenses. Built once in Flutter for web, mobile, and desktop. **Offline-first** on every device, with **encrypted multi-device cloud sync**.

---

## 1. What this app is

A single Flutter/Dart application that runs on **iOS, Android, Web (PWA), Windows, and macOS** (Linux best-effort) and lets one person:

- **Record transactions** manually or by **scanning/uploading documents** (receipts, invoices, bills, paychecks) which are parsed by **on-device OCR** into itemized transactions.
- **Categorize** every item (food, utilities, fun, …), including bills whose items span **multiple categories** (split transactions).
- **Analyze** spending and income through rich **visualizations and reports**.
- Work in **multiple currencies** with a chosen home/base currency for reporting.
- Use the app **fully offline**: every device keeps a complete, encrypted local database.
- Have data **sync seamlessly and encrypted across all their devices** (phone, laptop, web) through a cloud backend, with all devices converging automatically when online.

Because the app now hosts user data in the cloud, it carries real privacy and compliance obligations (GDPR controller/processor split, data residency, privacy policy, data export, and account deletion). This is a deliberate change from the previous local-only stance and is documented honestly in [09-security-privacy.md](09-security-privacy.md).

## 2. Key decisions (locked)

| Area | Decision |
|------|----------|
| Platform | **Flutter / Dart** single codebase across **web + mobile + desktop** (iOS, Android, Web/PWA, Windows, macOS) |
| UI framework | **Flutter + Material 3**, design-token theming via `ThemeExtension`; responsive/adaptive layouts |
| Document scanning | **Platform-adaptive on-device OCR** (ML Kit / Apple Vision / Tesseract / Tesseract.js), optional opt-in cloud fallback |
| Data storage | **Offline-first encrypted SQLite (Drift)** on device **+ Supabase cloud sync** (PowerSync); client-side encryption for attachments & sensitive payloads |
| Currency | **Multi-currency** with base-currency reporting |

See [03-architecture.md](03-architecture.md) for the reasoning and [10-risks-and-decisions.md](10-risks-and-decisions.md) for the decision log (ADRs).

## 3. Document index

| # | Document | Purpose |
|---|----------|---------|
| 00 | [README](00-README.md) | This index & overview |
| 01 | [Product Requirements (PRD)](01-product-requirements.md) | Vision, personas, scope, user stories |
| 02 | [Functional & Non-Functional Requirements](02-functional-requirements.md) | Numbered, testable requirements |
| 03 | [Technical Architecture](03-architecture.md) | Stack, layers, components, libraries |
| 04 | [Data Model](04-data-model.md) | Entities, schema, relationships, money handling, sync columns |
| 05 | [OCR & Document Processing](05-ocr-document-processing.md) | On-device scan → structured transaction pipeline |
| 06 | [UX / UI Specification](06-ux-ui-spec.md) | Screens, adaptive navigation, wireframes |
| 07 | [Analytics & Visualizations](07-analytics-visualizations.md) | Charts, reports, metrics |
| 08 | [Implementation Roadmap](08-implementation-roadmap.md) | Phases, milestones, backlog |
| 09 | [Security & Privacy](09-security-privacy.md) | Encryption, sync security, cloud data protection, compliance |
| 10 | [Risks & Decision Log (ADRs)](10-risks-and-decisions.md) | Risks, mitigations, architecture decisions |
| 11 | [Analysis & Visualization Deep Dive](11-analysis-and-visualization-deep-dive.md) | Detailed spec of every analysis view, metric formula, cashflow/category/chart |
| 12 | [Design System & UX Principles](12-design-system-and-ux.md) | Finance-app UX rules, visual language, tokens, component library, accessibility |
| 13 | [Technical Implementation Plan](13-technical-implementation-plan.md) | Concrete build plan: project structure, packages, sync engine, OCR engines, CI/CD, packaging per platform |

## 4. How to read this

- **Want the big picture?** Read 01 (PRD) then 03 (Architecture).
- **Going to build it?** Read 02 (Requirements), 04 (Data Model), 13 (Technical Implementation Plan), 08 (Roadmap).
- **Working on scanning?** 05 (OCR pipeline).
- **Working on sync, auth, or cloud data?** 09 (Security & Privacy) + 04 (Data Model, sync columns) + 13 (Implementation Plan).
- **Working on the UI/charts?** 06 (UX screens) + 12 (design system & UX principles); 07 and 11 for analytics/visualizations.

## 5. Status

All documents are **draft v0.2** authored 2026-06-18, pre-implementation — **Flutter re-platform**. This revision re-targets the project from a Windows-only C#/.NET/WinUI app to a cross-platform Flutter app that is offline-first with encrypted cloud sync. No code has been written yet. The roadmap (08) and the technical implementation plan (13) define the first build phase.
