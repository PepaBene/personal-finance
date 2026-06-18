# Product Requirements Document (PRD)

**Project:** Personal Finance App (working title *Ledgerly*)
**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform

---

## 1. Vision

A private, offline-first personal-finance app that turns the chore of expense tracking into something fast and insightful — and that follows the user across every device they own. The user records spending by typing it in **or** by scanning a receipt/bill/paycheck; the app extracts the line items, helps categorize them (even across multiple categories per document), and surfaces clear visual insight into where money goes. Built once in Flutter, it runs on phone, laptop, desktop, and the web; each device works fully offline and **syncs encrypted across devices** when online.

**One-line pitch:** *Scan a receipt, get categorized line items, see your money clearly — on any device, working offline, synced and encrypted across all of them.*

## 2. Goals & non-goals

### Goals
- G1 — Make capturing a transaction take **< 10 seconds** manually and **< 30 seconds** via scan (review included).
- G2 — Accurately split a single document's items across **multiple categories**.
- G3 — Provide **analysis and visualizations** that answer "where is my money going?" at a glance.
- G4 — Keep financial data **encrypted everywhere**: at rest on device, in transit, and at rest in the cloud, with **client-side encryption** for attachments and sensitive payloads.
- G5 — Support **multiple currencies** with consistent base-currency reporting.
- G6 — Let one person's data **sync seamlessly across phone, laptop, and web**, offline-first, with all devices converging automatically when online.

### Non-goals (for now)
- NG1 — No multi-user / shared household accounts (single-user app; one account, many devices).
- NG2 — No direct bank-feed / Open Banking integration in v1 (manual + import + scan only).
- NG3 — No tax filing, no investment portfolio tracking, no double-entry accounting ledger semantics (this is personal finance, not bookkeeping software).
- NG4 — No bill-payment execution (it records, it doesn't pay).

> **Changed from v0.1:** Cloud sync and a cross-device experience are **no longer non-goals** — they are now core product features (see G6, US-21..US-25). The trade-off is real and accepted: hosting user data brings privacy and compliance obligations, documented in [09-security-privacy.md](09-security-privacy.md).

## 3. Target user (persona)

**"Pepa", the organized individual.**
- Tracks personal/household finances and moves between **a phone, a laptop, and the web** during a typical week.
- Comfortable with modern apps; wants speed, privacy, and **the same data wherever they are** — captures a receipt on the phone, reviews and analyzes on the laptop or web.
- Distrusts finance tools that mine data; expects strong encryption and the ability to export or delete everything.
- Receives and pays bills in more than one currency.
- Wants to *understand* spending, not just log it — values charts and trends.
- Will scan paper receipts on the phone and import the occasional PDF bill or paycheck on the desktop.

## 4. Top user stories

> Format: *As a user, I want … so that …*  Each maps to functional requirements in [02](02-functional-requirements.md).

### Capture
- US-1 — I want to **add a transaction manually** with date, amount, currency, merchant, and category so I can log spending quickly.
- US-2 — I want to **scan a paper receipt** (via phone camera, webcam, or image file) and have the app read its line items so I don't type them.
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
- US-16 — I want all data stored **encrypted**, unlocked with a password or device biometrics.
- US-17 — I want to **back up and restore** my data to a file.
- US-18 — I want to **export** transactions and reports (CSV / PDF).
- US-19 — I want to **import** existing data (CSV) from another tool or my bank statement.
- US-20 — I want to record **income** (paychecks) as well as expenses, and **transfers** between accounts.

### Sync & account
- US-21 — I want my data to **sync across my phone, laptop, and the web**, encrypted, and still work **fully offline**, so I always have the same up-to-date picture without depending on a connection.
- US-22 — I want changes I make on one device to **appear on my other devices within seconds** when they're online, with sensible **conflict resolution** if I edited the same thing in two places.
- US-23 — I want to **sign up and sign in** to my account (email + password or Apple/Google), and **sign out**, so my data is tied to me and protected.
- US-24 — I want to **unlock the app with biometrics or a local passcode** on devices that support it, so I'm not retyping my password constantly.
- US-25 — I want to **export all my data** and **delete my account and cloud data** on request, so I stay in control of my information.

## 5. Scope by release

| Release | Theme | Includes |
|---------|-------|----------|
| **MVP (v0.1)** | Capture + categorize + core charts + sync | Manual entry, categories (incl. splits), encrypted local DB, account sign-up/sign-in, **offline-first multi-device sync**, dashboard, spend-by-category & trend charts, multi-currency core, CSV import/export, backup/restore, responsive nav, light/dark themes |
| **v0.2** | Scanning | Image/PDF ingest, on-device OCR (platform-adaptive), line-item parsing, review screen, **encrypted attachments synced to cloud storage**, merchant memory & auto-categorization rules |
| **v0.3** | Deeper analysis | Budgets, recurring detection, advanced visualizations (treemap, calendar heatmap, waterfall), PDF report export |
| **v1.0** | Polish & release | Store releases (Play / App Store / Mac / Windows / Web PWA), onboarding, performance hardening, accessibility, localization (CS/EN), biometric unlock + auto-lock, end-to-end-encryption hardening, account deletion & data export |

Detailed phasing in [08-implementation-roadmap.md](08-implementation-roadmap.md); concrete build plan in [13-technical-implementation-plan.md](13-technical-implementation-plan.md).

## 6. Success metrics

- Manual transaction entry median time < 10s (measured in-app).
- Scan-to-saved median time < 30s including review.
- OCR field-level accuracy (total amount + date) ≥ 90% on typical printed receipts; line-item recall ≥ 70% (target, see [05](05-ocr-document-processing.md)).
- App cold-start < 2s; any analytics view renders < 1s on 10k transactions (each platform's native baseline).
- **Sync convergence:** a change made on one online device is reflected on the user's other online devices within **a few seconds** (target < 5s median); offline changes converge within seconds of reconnecting, with no data loss.
- Encryption coverage: 100% of user financial data is encrypted at rest on device, in transit, and at rest in the cloud (verifiable); attachments and sensitive payloads are additionally client-side encrypted.

## 7. Constraints & assumptions

- Runs on **iOS, Android, Web (PWA), Windows, and macOS** from a single Flutter/Dart codebase; Linux is best-effort/dev-only. Single primary user per account, used across multiple devices.
- **Offline-first:** every device holds a complete encrypted local database and is fully functional with no internet connection; sync is an enhancement, never a prerequisite for core use.
- **Cloud-backed:** an authenticated cloud backend stores each user's data (under tenant isolation) and propagates changes between the user's devices. Conflicts are resolved per-row (last-write-wins on `updatedAt`), with children keyed to their parent.
- OCR is **on-device** and platform-adaptive; accuracy is bounded by the platform's engine — a human review step is **always** required for scans. An opt-in cloud OCR fallback may be offered for hard documents.
- Exchange rates are entered/imported manually or via optional on-demand online fetch; see [04](04-data-model.md).
- Security model defends data at rest on device, in transit, and at rest in the cloud, and relies on tenant isolation plus client-side encryption for sensitive data; it does not defend a fully compromised OS or a lost-and-unrecovered encryption key.
