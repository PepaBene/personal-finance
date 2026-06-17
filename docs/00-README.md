# Personal Accounting App — Documentation

> **Working title:** *Ledgerly* (provisional — rename freely)
> A native Windows desktop application for recording, scanning, categorizing, and analyzing personal expenses. Local-first and privacy-focused.

---

## 1. What this app is

A standalone Windows desktop app (not a PWA, not a website) that lets one person:

- **Record transactions** manually or by **scanning/uploading documents** (receipts, invoices, bills, paychecks) which are parsed **offline** into itemized transactions.
- **Categorize** every item (food, utilities, fun, …), including bills whose items span **multiple categories** (split transactions).
- **Analyze** spending and income through rich **visualizations and reports**.
- Work in **multiple currencies** with a chosen home/base currency for reporting.
- Keep all data **local and encrypted** on the user's PC.

## 2. Key decisions (locked)

| Area | Decision |
|------|----------|
| Platform | Native Windows desktop, **C# 14 / .NET 10 (LTS)** |
| UI framework | **WinUI 3** (Windows App SDK 2.0) primary; **WPF** documented fallback |
| Document scanning | **Local / offline OCR only** (no cloud) |
| Data storage | **Local-only, encrypted SQLite** (SQLCipher) |
| Currency | **Multi-currency** with base-currency reporting |

See [03-architecture.md](03-architecture.md) for the reasoning and [10-risks-and-decisions.md](10-risks-and-decisions.md) for the decision log (ADRs).

## 3. Document index

| # | Document | Purpose |
|---|----------|---------|
| 00 | [README](00-README.md) | This index & overview |
| 01 | [Product Requirements (PRD)](01-product-requirements.md) | Vision, personas, scope, user stories |
| 02 | [Functional & Non-Functional Requirements](02-functional-requirements.md) | Numbered, testable requirements |
| 03 | [Technical Architecture](03-architecture.md) | Stack, layers, components, libraries |
| 04 | [Data Model](04-data-model.md) | Entities, schema, relationships, money handling |
| 05 | [OCR & Document Processing](05-ocr-document-processing.md) | Offline scan → structured transaction pipeline |
| 06 | [UX / UI Specification](06-ux-ui-spec.md) | Screens, navigation, wireframes |
| 07 | [Analytics & Visualizations](07-analytics-visualizations.md) | Charts, reports, metrics |
| 08 | [Implementation Roadmap](08-implementation-roadmap.md) | Phases, milestones, backlog |
| 09 | [Security & Privacy](09-security-privacy.md) | Encryption, data protection, backups |
| 10 | [Risks & Decision Log (ADRs)](10-risks-and-decisions.md) | Risks, mitigations, architecture decisions |
| 11 | [Analysis & Visualization Deep Dive](11-analysis-and-visualization-deep-dive.md) | Detailed spec of every analysis view, metric formula, cashflow/category/chart |
| 12 | [Design System & UX Principles](12-design-system-and-ux.md) | Finance-app UX rules, visual language, tokens, component library, accessibility |

## 4. How to read this

- **Want the big picture?** Read 01 (PRD) then 03 (Architecture).
- **Going to build it?** Read 02 (Requirements), 04 (Data Model), 08 (Roadmap).
- **Working on scanning?** 05 (OCR pipeline).
- **Working on the UI/charts?** 06 (UX screens) + 12 (design system & UX principles); 07 and 11 for analytics/visualizations.

## 5. Status

All documents are **draft v0.1** authored 2026-06-09, pre-implementation. No code has been written yet. The roadmap (08) defines the first build phase.
