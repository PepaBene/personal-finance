# UX / UI Specification

**Version:** 0.1 · **Date:** 2026-06-09
**Framework:** WinUI 3 / Fluent (Windows App SDK 2.0), MVVM. Light/dark themes, scalable type.
**Companion:** [12-design-system-and-ux.md](12-design-system-and-ux.md) defines the visual language, finance-UX principles, design tokens, and component library that these screens are built from. 06 = *what* screens exist; 12 = *how* they look and the rules behind them.

---

## 1. Information architecture

Primary navigation is a left **NavigationView** (collapsible rail) with these destinations:

```
🏠 Dashboard
💳 Transactions
📷 Scan / Import
🏷  Categories
📊 Analytics
🎯 Budgets
🏦 Accounts
⚙️  Settings
```

A persistent top bar holds: global **search**, the active **date-range / base-currency** filter chip, and a prominent **＋ Add** button (quick add transaction) and **Scan** button.

## 2. Screen-by-screen

### 2.1 Lock screen (FR-SEC-02)
Master-password prompt on launch (and after auto-lock). Optional "Unlock with Windows Hello". No data visible until unlocked.

### 2.2 Dashboard (FR-ANL-01)
The at-a-glance home. Cards/tiles:
- **This month**: Income, Expense, Net — with delta vs last month.
- **Account balances** (per account + total in base currency).
- **Top categories** this month (mini bar/donut).
- **Budget status** (progress bars for tracked categories; v0.3).
- **Spending trend** sparkline (last 6 months).
- **Recent transactions** list (last 5–10) with quick edit.
- Quick actions: Add transaction, Scan document.

### 2.3 Transactions (FR-CAP, FR-ANL-05)
- Virtualized, sortable, filterable **data grid**: Date · Merchant · Category(ies) · Account · Amount (orig) · Amount (base) · Source icon · Attachment icon.
- Row expands to show **line items** (the split). Multi-category rows show category chips.
- Filter bar: date range, type, category, account, currency, merchant, tag, text search.
- Bulk actions: re-categorize, delete, export selection.
- **Add/Edit transaction dialog** (see 2.4).

### 2.4 Add / Edit transaction (FR-CAP-01..05)
- Fields: type toggle (Expense/Income/Transfer), date, merchant (autocomplete), account, currency, total.
- **Line items editor**: add rows (description, qty, unit price, amount, **category picker**, tags). Running **balance indicator** shows Σlines vs total and warns if unbalanced (FR-CAP-05).
- "Single category" quick mode for simple expenses (one implicit line).
- Attach document button. Save / Save & New.

### 2.5 Scan / Import (FR-SCAN)
- Drop zone + buttons: *From file*, *From scanner*, *From webcam*, *From PDF*.
- Progress while OCR runs (cancelable).
- **Review screen** (the heart of scanning): split layout —
  - **Left:** original document with OCR bounding-box overlays; click a field to highlight its source region.
  - **Right:** editable extracted form (merchant/date/total/currency) + line-item table with category pickers; **low-confidence fields highlighted** (FR-SCAN-11).
  - Footer: reconciliation status (Σlines vs total), doc-type override, Save.
- CSV import wizard (separate flow): pick file → map columns → preview → import (FR-DAT-05).

### 2.6 Categories (FR-CAT)
- Tree view of categories/subcategories with icon + color.
- Add/rename/recolor/reorder/archive. Drag to re-parent.
- Manage **auto-categorization rules** (list, priority order, enable/disable) and merchant→category memory.

### 2.7 Analytics (FR-ANL)
Tabbed or sectioned workspace, all honoring the global filter & base currency:
- **By category** — donut/treemap with drill-down.
- **Over time** — line / stacked-area by period.
- **Income vs expense** — grouped bars.
- **Comparison** — MoM / YoY (v0.3).
- **Merchants** — top payees (v0.3).
- **Calendar heatmap** & **cash-flow waterfall** (v0.3).
Clicking any segment drills to the underlying transaction list (FR-ANL-10). See [07](07-analytics-visualizations.md).

### 2.8 Budgets (FR-BUD, v0.3)
- Per-category monthly budget setup.
- Actual-vs-budget bars with over/under coloring and alerts.

### 2.9 Accounts (FR-ACC)
- List of accounts with kind, currency, current balance.
- Add/edit/archive; opening balance; transfer helper.

### 2.10 Settings (FR-SEC, FR-CUR, NFR-08)
- **Security**: change master password, Windows Hello toggle, auto-lock timeout.
- **Currency**: base currency, manage currencies & exchange rates (manual entry + optional fetch).
- **OCR**: engine selection, languages, preprocessing toggles.
- **Appearance**: theme, accent, font scale, locale (CS/EN).
- **Data**: backup now, restore, export (CSV/PDF), import, purge soft-deleted.

## 3. Interaction & design principles

- **Speed**: keyboard-first entry; Enter/Tab flow through the add form; global `Ctrl+N` (new), `Ctrl+S` (scan), `Ctrl+F` (search).
- **2-click reachability** for primary tasks (NFR-06).
- **Undo** toasts for deletes; soft-delete backing.
- **Non-blocking** long operations (OCR) with progress + cancel.
- **Confidence cues** in scanning: color-coded field borders (green/amber/red).
- **Empty states** with guidance (e.g. first run → "Add your first transaction or scan a receipt").
- **Drill-down everywhere**: charts and summary tiles are clickable into filtered lists.

## 4. Visual language

- Fluent design: acrylic/mica surfaces, rounded corners, system accent.
- Category **color + icon** used consistently across grid chips, pickers, and charts (single source of truth from the Category entity).
- Money formatting is locale- & currency-aware; base-currency totals visually distinguished from original-currency amounts.
- Light & dark themes; high-contrast variant (NFR-07).

## 5. Accessibility (NFR-07)

- Full keyboard navigation and focus order; `AutomationProperties` labels for screen readers; sufficient contrast; resizable text; no information conveyed by color alone (confidence also shown via icon/text).

## 6. Onboarding (v1.0)

First-run wizard: set base currency & locale → set master password → choose default categories / accept seed set → optional sample data → land on Dashboard.

## 7. Wireframe sketches (textual)

```
DASHBOARD
┌──────────────────────────────────────────────────────────────┐
│ [Search......]      [Jun 2026 ▾] [Base: EUR ▾]   [＋ Add][Scan]│
├──────┬───────────────────────────────────────────────────────┤
│ Nav  │ ┌Income┐ ┌Expense┐ ┌ Net ┐ ┌ Balances ───────────┐    │
│ 🏠   │ │ +X ▲ │ │ -Y  ▼ │ │  Z  │ │ Cash.. Bank.. Card..│    │
│ 💳   │ └──────┘ └───────┘ └─────┘ └─────────────────────┘    │
│ 📷   │ ┌ Top categories (donut) ┐ ┌ Trend (6 mo sparkline) ┐ │
│ 🏷   │ │       ◖◗               │ │      ╱╲___╱            │ │
│ 📊   │ └───────────────────────┘ └───────────────────────┘ │
│ 🎯   │ ┌ Recent transactions ──────────────────────────────┐ │
│ 🏦   │ │ 08.06  Albert   Groceries+2   842 CZK  (33.68 €) 📎│ │
│ ⚙️   │ └───────────────────────────────────────────────────┘ │
└──────┴───────────────────────────────────────────────────────┘

SCAN REVIEW
┌──────────────────────────────────────────────────────────────┐
│ Document review            doc type: [Receipt ▾]   [Save ✓]   │
├───────────────────────────┬──────────────────────────────────┤
│  [original image w/ OCR   │ Merchant [Albert        ] 🟢      │
│   bounding boxes; click a │ Date     [08.06.2026    ] 🟢      │
│   line to highlight here] │ Total    [842,00] CZK    🟡      │
│                           │ ── line items ──────────────────  │
│                           │ Milk 1L x2   49,80  [Groceries ▾] │
│                           │ Dish soap    89,90  [Household ▾] │
│                           │ Beer 6pk    149,40  [Alcohol  ▾]🟡│
│                           │ Σ lines 842,00 == total ✓         │
└───────────────────────────┴──────────────────────────────────┘
```
