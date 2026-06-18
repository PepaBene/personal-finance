# UX / UI Specification

**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform
**Framework:** **Flutter + Material 3**, MVVM with Riverpod ViewModels (`Notifier`/`AsyncNotifier`). Adaptive/responsive across web, mobile, and desktop (incl. Windows + macOS). Light/dark/high-contrast themes, scalable type.
**Companion:** [12-design-system-and-ux.md](12-design-system-and-ux.md) defines the visual language, finance-UX principles, design tokens (Material 3 `ThemeExtension`), and component library that these screens are built from. 06 = *what* screens exist; 12 = *how* they look and the rules behind them.

---

## 1. Information architecture

The same destinations exist on every platform; only the **navigation chrome adapts** to form factor via breakpoints:

- **Mobile (compact, < 600 dp):** Material 3 **NavigationBar** (bottom) with the primary destinations; overflow + Settings reachable from the bar or app bar.
- **Tablet / small desktop (medium, 600–1240 dp):** **NavigationRail** (icons + labels).
- **Desktop / web (expanded, ≥ 1240 dp):** **extended NavigationRail / drawer** (icons + text labels, optionally collapsible).

Destinations (unchanged set):

```
🏠 Dashboard      📊 Analytics
💳 Transactions   🎯 Budgets
📷 Scan / Import  🏦 Accounts
🏷  Categories    ⚙️  Settings
```

A persistent **account / sync indicator** lives in the navigation region (avatar + sync status: synced / syncing / offline / error) and opens the Account & Sync settings.

A persistent **top app bar** (adapted per platform) holds: global **search**, the active **date-range / base-currency** filter chip, a prominent **＋ Add** button (quick add transaction), and a **Scan** button. On mobile, secondary actions collapse into the app bar overflow and the ＋ Add becomes a **FloatingActionButton**; on desktop/web the full action set is shown inline.

## 2. Screen-by-screen

Each screen is **responsive**: mobile presents a single column; tablet/desktop/web present multi-pane or wider layouts. Interactions support **touch, keyboard, and mouse** (tap/long-press, hover, right-click context menus, keyboard shortcuts and focus order).

### 2.1 Lock & Sign-in (FR-SEC-02, FR-AUTH-01)
- **Sign-in / Account screen** (Supabase Auth): email + password, OAuth (Apple / Google), and magic link. First launch routes here unless a valid session exists; supports sign-up, password reset, and recovery-phrase entry for E2E-encrypted data (see [09](09-security-privacy.md), ADR-012).
- **Lock screen**: after the app auto-locks (idle) or on cold start of an authenticated session, the user unlocks with **biometric / local unlock via local_auth** (Face ID / Touch ID / Android biometrics / Windows Hello / macOS Touch ID). Web and devices without biometrics fall back to a passphrase. No data is visible until unlocked.
- A **sync-status indicator** is visible post-unlock (synced / syncing / offline / conflict).

### 2.2 Dashboard (FR-ANL-01)
The at-a-glance home. Cards/tiles (single-column stack on mobile; responsive grid on wider screens):
- **This month**: Income, Expense, Net — with delta vs last month.
- **Account balances** (per account + total in base currency).
- **Top categories** this month (mini bar/donut, **fl_chart**).
- **Budget status** (progress bars for tracked categories; v0.3).
- **Spending trend** sparkline (last 6 months).
- **Recent transactions** list (last 5–10) with quick edit (tap on mobile, hover-edit on desktop).
- Quick actions: Add transaction, Scan document.

### 2.3 Transactions (FR-CAP, FR-ANL-05)
- Sortable, filterable, virtualized transaction list. On **desktop/web** it renders as a multi-column **data table** (Date · Merchant · Category(ies) · Account · Amount (orig) · Amount (base) · Source icon · Attachment icon); on **mobile** it collapses to a **list of cards** with the key fields and an expandable detail.
- A row expands to show **line items** (the split); multi-category rows show category chips.
- **Filter bar** (responsive — inline on desktop, bottom-sheet on mobile): date range, type, category, account, currency, merchant, tag, text search.
- **Bulk actions** (multi-select via checkboxes / long-press): re-categorize, delete, export selection.
- **Add/Edit** opens a dialog on desktop/web and a full-screen route / bottom sheet on mobile (see 2.4).

### 2.4 Add / Edit transaction (FR-CAP-01..05)
- Fields: type toggle (Expense/Income/Transfer), date, merchant (autocomplete), account, currency, total.
- **Line items editor**: add rows (description, qty, unit price, amount, **category picker**, tags). A running **balance indicator** shows Σlines vs total and warns if unbalanced (FR-CAP-05).
- "Single category" quick mode for simple expenses (one implicit line).
- Attach document button. Save / Save & New.
- **Input adapts**: keyboard Tab/Enter flow and shortcuts on desktop; large touch targets, numeric keypad, and swipe-to-delete rows on mobile.

### 2.5 Scan / Import (FR-SCAN)
- Entry surface: **drop zone** (desktop/web drag-and-drop) + buttons: *From file*, *From camera*, *From PDF* (and document-scanner / webcam where available). Camera capture uses the platform document scanner on mobile.
- Progress while OCR runs (cancelable), driven by the `ScanService` progress `Stream` (see [05 §3](05-ocr-document-processing.md)). Heavy work runs in isolates so the UI stays responsive.
- **Review screen** (the heart of scanning) — **adaptive layout**:
  - **Desktop / tablet / web:** split view — **left** the original document with OCR bounding-box overlays (tap/click a field to highlight its source region); **right** the editable extracted form (merchant/date/total/currency) + line-item table with category pickers.
  - **Mobile:** the same panes **stack vertically** (image on top, scrollable form below); tapping a field scrolls/zooms the image to its source region.
  - **Low-confidence fields highlighted** (FR-SCAN-11). Footer: reconciliation status (Σlines vs total), doc-type override, Save.
- **CSV import wizard** (separate flow): pick file → map columns → preview → import (FR-DAT-05); responsive stepper.

### 2.6 Categories (FR-CAT)
- Tree view of categories/subcategories with icon + color.
- Add/rename/recolor/reorder/archive. Re-parent via drag (desktop/web) or a move action (mobile).
- Manage **auto-categorization rules** (list, priority order, enable/disable) and merchant→category memory.

### 2.7 Analytics (FR-ANL)
Tabbed or sectioned workspace, all honoring the global filter & base currency; charts via **fl_chart** (advanced treemap/heatmap via syncfusion where noted), styled from the same design tokens as the UI:
- **By category** — donut/treemap with drill-down.
- **Over time** — line / stacked-area by period.
- **Income vs expense** — grouped bars.
- **Comparison** — MoM / YoY (v0.3).
- **Merchants** — top payees (v0.3).
- **Calendar heatmap** & **cash-flow waterfall** (v0.3).
Tapping/clicking any segment drills to the underlying transaction list (FR-ANL-10). Layout reflows to single-column stacked charts on mobile. See [07](07-analytics-visualizations.md).

### 2.8 Budgets (FR-BUD, v0.3)
- Per-category monthly budget setup.
- Actual-vs-budget bars with over/under coloring and alerts.

### 2.9 Accounts (FR-ACC)
- List of accounts with kind, currency, current balance.
- Add/edit/archive; opening balance; transfer helper.

### 2.10 Settings (FR-SEC, FR-CUR, FR-AUTH, FR-SYNC, NFR-08)
- **Account & Sync** (new): signed-in identity (sign in / sign out), **Sync now** + last-sync status, **connected devices** list, **encryption / recovery phrase** (view/regenerate, re-enter), **data export** (CSV/PDF/full archive) and **account deletion** (right to erasure — see [09](09-security-privacy.md)).
- **Security**: **biometric / local unlock** toggle (local_auth), **auto-lock** timeout, optional MFA, change passphrase.
- **Currency**: base currency, manage currencies & exchange rates (manual entry + optional fetch).
- **OCR**: engine info (platform-adaptive, on-device by default), languages (CS/EN), preprocessing toggles, and the **opt-in cloud OCR fallback** toggle (see [05 §3](05-ocr-document-processing.md)).
- **Appearance**: theme (light/dark/high-contrast), accent / dynamic color, font scale, locale (CS/EN).
- **Data**: backup now, restore, import, purge soft-deleted. (Export & deletion live under Account & Sync.)

## 3. Interaction & design principles

- **Speed**: keyboard-first entry on desktop/web; Enter/Tab flow through the add form; shortcuts `Ctrl/Cmd+N` (new), `Ctrl/Cmd+K` (search), `Ctrl/Cmd+Shift+S` (scan). Mobile favors gestures (swipe-to-delete, pull-to-refresh, long-press multi-select) and large touch targets.
- **2-click / 2-tap reachability** for primary tasks (NFR-06).
- **Undo** toasts (Material `SnackBar`) for deletes; soft-delete backing (which also drives sync tombstones).
- **Non-blocking** long operations (OCR, sync) with progress + cancel; work runs in isolates / background.
- **Confidence cues** in scanning: color-coded field borders (green/amber/red) plus an icon (never color alone).
- **Sync awareness**: a global indicator shows synced / syncing / offline / conflict; offline edits are accepted and reconciled on reconnect.
- **Empty states** with guidance (e.g. first run → "Add your first transaction or scan a receipt").
- **Drill-down everywhere**: charts and summary tiles are clickable/tappable into filtered lists.

## 4. Visual language

- **Material 3**: tonal surfaces, rounded corners, `ColorScheme.fromSeed`; dynamic color on Android 12+; elevation/state layers per M3. Design tokens via `ThemeExtension` (see [12](12-design-system-and-ux.md)).
- Category **color + icon** used consistently across list chips, pickers, and charts (single source of truth from the Category entity).
- Money formatting is locale- & currency-aware (intl `NumberFormat`), with **tabular figures**; base-currency totals are visually distinguished from original-currency amounts.
- Light, dark, and high-contrast themes (NFR-07); respects platform reduce-motion (`MediaQuery.disableAnimations`).

## 5. Accessibility (NFR-07)

- Full keyboard navigation and logical focus order; **Flutter `Semantics`** labels for screen readers (TalkBack / VoiceOver / Narrator); sufficient contrast (AA); text scaling honored via `MediaQuery.textScaler`; no information conveyed by color alone (confidence and sync state also shown via icon/text). Touch targets meet platform minimum sizes.

## 6. Onboarding (v1.0)

First-run flow: **create account / sign in** (Supabase Auth) → **set up encryption** (passphrase → generate & confirm **recovery phrase**, see [09](09-security-privacy.md), ADR-012) → set base currency & locale → enable **biometric unlock** (optional) → choose default categories / accept seed set → optional sample data → land on Dashboard. Returning devices sign in and sync down existing data.

## 7. Wireframe sketches (textual)

```
DASHBOARD — desktop / web (expanded: extended NavigationRail)
┌──────────────────────────────────────────────────────────────┐
│ [Search......]      [Jun 2026 ▾] [Base: EUR ▾]   [＋ Add][Scan]│
├──────┬───────────────────────────────────────────────────────┤
│ Rail │ ┌Income┐ ┌Expense┐ ┌ Net ┐ ┌ Balances ───────────┐    │
│ 🏠   │ │ +X ▲ │ │ -Y  ▼ │ │  Z  │ │ Cash.. Bank.. Card..│    │
│ 💳   │ └──────┘ └───────┘ └─────┘ └─────────────────────┘    │
│ 📷   │ ┌ Top categories (donut) ┐ ┌ Trend (6 mo sparkline) ┐ │
│ 🏷   │ │       ◖◗               │ │      ╱╲___╱            │ │
│ 📊   │ └───────────────────────┘ └───────────────────────┘ │
│ 🎯   │ ┌ Recent transactions ──────────────────────────────┐ │
│ 🏦   │ │ 08.06  Albert   Groceries+2   842 CZK  (33.68 €) 📎│ │
│ ⚙️   │ └───────────────────────────────────────────────────┘ │
│ ◍sync│                                                        │
└──────┴───────────────────────────────────────────────────────┘

DASHBOARD — mobile (compact: bottom NavigationBar + FAB)
┌───────────────────────────────┐
│ ☰  Ledgerly   [Jun ▾]  🔍 ◍   │
├───────────────────────────────┤
│ ┌Income┐ ┌Expense┐ ┌ Net ┐    │
│ │ +X ▲ │ │ -Y  ▼ │ │  Z  │    │
│ └──────┘ └───────┘ └─────┘    │
│ ┌ Top categories (donut) ────┐│
│ │            ◖◗              ││
│ └────────────────────────────┘│
│ ┌ Recent ───────────────────┐ │
│ │ 08.06 Albert  842 CZK   📎│ │
│ └───────────────────────────┘ │
│                          (＋) │
├───────────────────────────────┤
│ 🏠   💳   📷   📊   ⚙️         │
└───────────────────────────────┘

SCAN REVIEW — desktop (split view)
┌──────────────────────────────────────────────────────────────┐
│ Document review            doc type: [Receipt ▾]   [Save ✓]   │
├───────────────────────────┬──────────────────────────────────┤
│  [original image w/ OCR   │ Merchant [Albert        ] 🟢      │
│   bounding boxes; tap a   │ Date     [08.06.2026    ] 🟢      │
│   line to highlight here] │ Total    [842,00] CZK    🟡      │
│                           │ ── line items ──────────────────  │
│                           │ Milk 1L x2   49,80  [Groceries ▾] │
│                           │ Dish soap    89,90  [Household ▾] │
│                           │ Beer 6pk    149,40  [Alcohol  ▾]🟡│
│                           │ Σ lines 842,00 == total ✓         │
└───────────────────────────┴──────────────────────────────────┘

SCAN REVIEW — mobile (stacked: image pane on top, form below)
┌───────────────────────────────┐
│ Review   [Receipt ▾]  [Save ✓]│
├───────────────────────────────┤
│ [original image w/ OCR boxes  │
│  — tap field below to focus]  │
├───────────────────────────────┤
│ Merchant [Albert      ]   🟢  │
│ Date     [08.06.2026  ]   🟢  │
│ Total    [842,00] CZK     🟡  │
│ ── line items ──────────────  │
│ Milk 1L x2  49,80 [Groceries]│
│ Beer 6pk   149,40 [Alcohol] 🟡│
│ Σ lines 842,00 == total ✓     │
└───────────────────────────────┘
```
