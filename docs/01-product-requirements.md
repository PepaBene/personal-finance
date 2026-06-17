# Product Requirements Document (PRD)

**Project:** Personal Accounting App (working title *Ledgerly*)
**Version:** 0.1 (draft) · **Date:** 2026-06-09 · **Status:** Pre-implementation

---

## 1. Vision

A private, offline-first Windows desktop app that turns the chore of personal expense tracking into something fast and insightful. The user records spending by typing it in **or** by scanning a receipt/bill/paycheck; the app extracts the line items, helps categorize them (even across multiple categories per document), and surfaces clear visual insight into where money goes.

**One-line pitch:** *Scan a receipt, get categorized line items, see your money clearly — all on your own PC, no cloud.*

## 2. Goals & non-goals

### Goals
- G1 — Make capturing a transaction take **< 10 seconds** manually and **< 30 seconds** via scan (review included).
- G2 — Accurately split a single document's items across **multiple categories**.
- G3 — Provide **analysis and visualizations** that answer "where is my money going?" at a glance.
- G4 — Keep **100% of financial data local and encrypted**; nothing leaves the device.
- G5 — Support **multiple currencies** with consistent base-currency reporting.

### Non-goals (for now)
- NG1 — No multi-user / shared household accounts (single-user app).
- NG2 — No cloud sync or mobile companion app (may revisit later via encrypted export).
- NG3 — No direct bank-feed / Open Banking integration in v1 (manual + import + scan only).
- NG4 — No tax filing, no investment portfolio tracking, no double-entry accounting ledger semantics (this is personal finance, not bookkeeping software).
- NG5 — No bill-payment execution (it records, it doesn't pay).

## 3. Target user (persona)

**"Pepa", the organized individual.**
- Tracks personal/household finances on a Windows 11 PC.
- Comfortable with desktop apps; wants speed and privacy, distrusts cloud finance tools.
- Receives and pays bills in more than one currency.
- Wants to *understand* spending, not just log it — values charts and trends.
- Will scan paper receipts and import the occasional PDF bill or paycheck.

## 4. Top user stories

> Format: *As a user, I want … so that …*  Each maps to functional requirements in [02](02-functional-requirements.md).

### Capture
- US-1 — I want to **add a transaction manually** with date, amount, currency, merchant, and category so I can log spending quickly.
- US-2 — I want to **scan a paper receipt** (via webcam/scanner or image file) and have the app read its line items so I don't type them.
- US-3 — I want to **upload a PDF invoice/bill/paycheck** and have items and amounts extracted automatically.
- US-4 — I want to **review and correct** any auto-extracted data before it's saved, because OCR isn't perfect.
- US-5 — I want to **attach the original document** to the transaction so I can find the source later.

### Categorize
- US-6 — I want to assign each item to a **category** (food, utilities, fun, …).
- US-7 — I want a single bill to **split across multiple categories** (e.g. a supermarket trip = food + household + alcohol).
- US-8 — I want the app to **remember** how I categorized a merchant/item and **auto-suggest** next time.
- US-9 — I want to create my own **categories and subcategories**.

### Analyze
- US-10 — I want a **dashboard** showing this month's spending, income, balance, and top categories.
- US-11 — I want to see **spending by category** as a pie/donut/treemap.
- US-12 — I want **trends over time** (line/stacked-area), and **month-over-month / year-over-year** comparisons.
- US-13 — I want to **filter** any view by date range, category, currency, merchant, account, and tag.
- US-14 — I want to set **budgets per category** and see actual-vs-budget progress.
- US-15 — I want to **detect recurring/subscription** spending.

### Manage & protect
- US-16 — I want all data stored **locally and encrypted**, unlocked with a password.
- US-17 — I want to **back up and restore** my data to a file.
- US-18 — I want to **export** transactions and reports (CSV / PDF).
- US-19 — I want to **import** existing data (CSV) from another tool or my bank statement.
- US-20 — I want to record **income** (paychecks) as well as expenses, and **transfers** between accounts.

## 5. Scope by release

| Release | Theme | Includes |
|---------|-------|----------|
| **MVP (v0.1)** | Capture + categorize + core charts | Manual entry, categories (incl. splits), encrypted local DB, dashboard, spend-by-category & trend charts, multi-currency core, CSV import/export, backup/restore |
| **v0.2** | Scanning | Image/PDF ingest, offline OCR, line-item parsing, review screen, document attachments, merchant memory & auto-categorization rules |
| **v0.3** | Deeper analysis | Budgets, recurring detection, advanced visualizations (treemap, calendar heatmap, waterfall), PDF report export |
| **v1.0** | Polish | MSIX installer + auto-update, onboarding, performance hardening, accessibility, localization (CS/EN) |

Detailed phasing in [08-implementation-roadmap.md](08-implementation-roadmap.md).

## 6. Success metrics

- Manual transaction entry median time < 10s (measured in-app).
- Scan-to-saved median time < 30s including review.
- OCR field-level accuracy (total amount + date) ≥ 90% on typical printed receipts; line-item recall ≥ 70% (target, see [05](05-ocr-document-processing.md)).
- App cold-start < 2s; any analytics view renders < 1s on 10k transactions.
- Zero network egress of user financial data (verifiable: app works fully offline / firewalled).

## 7. Constraints & assumptions

- Windows 10 (1809+) / Windows 11 x64. Single primary user per installation.
- Offline-first: must be fully functional with no internet connection.
- OCR is local; accuracy is bounded by on-device engines — a human review step is **always** required for scans.
- Exchange rates are entered/imported manually or via optional one-off online fetch (no always-on connection assumed); see [04](04-data-model.md).
- The user trusts their own machine; security model defends data-at-rest, not a compromised OS.
