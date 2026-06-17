# Design System & UX Principles

**Version:** 0.1 · **Date:** 2026-06-09
**Scope:** The single source of truth for how the app *looks, feels, and behaves*. Complements the screen-by-screen spec in [06-ux-ui-spec.md](06-ux-ui-spec.md) (06 = *what* screens exist; this doc = *how* they should look and the rules behind them). Realized on **WinUI 3 / Fluent (Windows App SDK 2.0)** with a custom token layer. Tracked as ADR-009 in [10](10-risks-and-decisions.md).

---

## 1. Design vision

> **Calm, trustworthy, and fast.** A finance app earns trust through clarity, not decoration. Every screen should make the user feel *in control of their money and their data*.

Three adjectives that govern every decision: **Clean · Modern · Effortless.**

- **Clean** — generous whitespace, one primary action per screen, no visual clutter, data-ink over chrome.
- **Modern** — Fluent design (Mica/acrylic, rounded geometry, smooth motion), system accent, light/dark.
- **Effortless** — the common task is the default path; the app anticipates, remembers, and forgives.

## 2. Finance-app UX principles (the rules)

These are domain-specific principles, not generic platitudes. Each is testable.

| # | Principle | What it means here |
|---|-----------|--------------------|
| P1 | **Clarity over cleverness** | Numbers, dates, and categories are unambiguous. No mystery icons for money. Labels always accompany figures. |
| P2 | **Trust through transparency** | Always show *how* a number was derived (e.g. base-currency amount shows original + rate on hover). Never hide where money went. |
| P3 | **Accuracy is sacred** | Money is right-aligned, monospaced-tabular, fixed decimals, currency-marked. Never truncate an amount. Rounding shown, not silent. |
| P4 | **Color carries meaning, consistently** | Expense vs income vs transfer, over/under budget, positive/negative deltas use one fixed semantic palette everywhere. Color is never the *only* signal (P11). |
| P5 | **Progressive disclosure** | Simple by default (one-line expense), depth on demand (expand to line items / splits). Don't overwhelm new users. |
| P6 | **Speed is a feature** | Capturing a transaction is the most frequent task — it must be the fastest. Keyboard-first, smart defaults, < 10s (G1). |
| P7 | **Forgiveness** | Every destructive action is undoable (soft-delete + toast). Confirm only truly irreversible actions. Inline validation prevents errors before they happen. |
| P8 | **Recognition over recall** | Autocomplete merchants/categories; remember last choices; suggest categories. The user picks, doesn't remember. |
| P9 | **Consistency** | One way to do a thing. Same control for the same job across all screens. Category color+icon identical in grid, picker, and chart. |
| P10 | **Respect attention** | No nagging, no dark patterns, no upsell. Alerts (budget over) are calm and dismissible. The app is a tool, not a casino. |
| P11 | **Accessible by default** | WCAG 2.1 AA targets; keyboard, screen reader, contrast, scalable text; never color-only meaning (NFR-07). |
| P12 | **Privacy is visible** | An always-available indicator/affordance reinforces "your data is local & encrypted." Lock is one click. |
| P13 | **Empty states teach** | First-run and empty views guide the next action instead of showing a blank void. |
| P14 | **Honest data viz** | Axes start at zero for bars; no misleading scales; comparisons are like-for-like; "no data" is stated, not faked. |

## 3. Visual language

### 3.1 Layout & spacing
- **8-pt grid.** All spacing/sizing in multiples of 4 (micro) / 8 (standard): `4, 8, 12, 16, 24, 32, 48, 64`.
- **Content max-width** for forms/reading (~720px) so lines don't sprawl on wide monitors; data grids and charts use full width.
- **Card-based surfaces** with consistent corner radius and a subtle elevation/stroke; cards group related info (dashboard tiles, chart panels).
- Comfortable default density with an optional **compact density** toggle for power users with large datasets.

### 3.2 Color
A **token-based** palette (see §5) on top of the Windows accent.

- **Neutrals**: a 10-step gray ramp for surfaces, strokes, text (light + dark variants).
- **Brand/accent**: follows the user's Windows accent by default; one app accent fallback.
- **Semantic finance palette (fixed meaning):**
  - `positive / income` → green family
  - `negative / expense` → red family (used sparingly; expenses are the norm, so neutral by default and red reserved for *attention*, e.g. over-budget/negative net)
  - `transfer / neutral` → blue/gray family
  - `warning` (near budget) → amber; `danger` (over budget / negative balance) → red; `success` → green; `info` → blue.
- **Category colors**: a curated, **color-blind-aware** categorical palette (≥ 12 distinct hues) assigned to categories; this is the *single source of truth* used across chips, pickers, and every chart (P9).
- **Contrast**: text/background pairs meet **AA (4.5:1)**; large text/icons ≥ 3:1. Verified per token in both themes.

### 3.3 Typography
- **UI font**: Segoe UI Variable (Windows default) — native, legible, modern.
- **Numeric/money**: tabular (monospaced) figures so columns of amounts align (`font-variant-numeric: tabular-nums` equivalent / Segoe UI tabular).
- **Type scale** (Fluent ramp): Caption 12 · Body 14 · Body-Strong 14/600 · Subtitle 20 · Title 28 · Display 40. Line-height ~1.4 for body.
- Respect OS text scaling; layouts reflow, never clip (P11).

### 3.4 Iconography
- **Fluent System Icons** for a native, consistent set. One icon style throughout.
- Category icons from a curated subset; each category = one icon + one color, fixed everywhere.
- Icons are decorative-plus-label, never label-replacing for critical meaning (P1/P11).

### 3.5 Motion
- **Purposeful, quick, subtle.** Durations 100–250ms, Fluent easing. Motion communicates state change (navigation, expand/collapse, value updates), never decorates.
- Charts animate on first render and on data change (short, non-distracting). Number tickers for KPI changes are optional and brief.
- **Respect "reduce motion"** OS setting — disable non-essential animation (P11).

### 3.6 Elevation & materials
- Fluent **Mica** on the app backdrop, **acrylic** for transient surfaces (flyouts, dialogs). Cards use subtle shadow/stroke. Don't over-layer — depth signals hierarchy, not flair.

## 4. Component library

A curated set built on WinUI controls, themed via tokens. Each has defined states: *default, hover, pressed, focused, disabled, error, loading, empty*.

| Component | Notes / finance specifics |
|-----------|---------------------------|
| **App shell / NavigationView** | Left rail (collapsible), top command bar; persistent Add/Scan, search, filter chip, lock button. |
| **MoneyText** | Specialized display: right-aligned, tabular, currency symbol/code, sign-aware color, optional base+original tooltip. Reused everywhere money is shown (P3). |
| **AmountInput** | Numeric entry with currency picker, locale-aware decimal/grouping, inline validation, big tap target. |
| **CategoryPicker** | Searchable hierarchical picker showing color+icon; recently/most-used surfaced first (P8). |
| **CategoryChip** | Compact color+icon+label token used in grids and line items. |
| **MerchantAutoComplete** | Type-ahead over known merchants with logo/initial + last category hint. |
| **TransactionRow / SplitExpander** | Row with multi-category chips; expands to line-item editor. |
| **LineItemEditor** | Editable rows + live **balance indicator** (Σ lines vs total) with clear unbalanced state (FR-CAP-05). |
| **KpiCard** | Label, big value (MoneyText), delta badge (▲/▼ + %), optional sparkline. Delta color = semantic. |
| **ChartPanel** | Card wrapping a chart with title, period/grain control, legend, "show as table", export, empty state. |
| **FilterBar / FilterChips** | The global filter context (date range, type, category…); chips are removable; "save view." |
| **DateRangePicker** | Presets + custom; the most-used filter, prominent and fast. |
| **ConfidenceField** | Scan-review input with green/amber/red border + icon + text for OCR confidence (FR-SCAN-11). |
| **Toast / Undo snackbar** | Non-blocking feedback; undo for deletes (P7). |
| **EmptyState** | Illustration + one-line guidance + primary action (P13). |
| **Dialog / Flyout** | Acrylic, focus-trapped, keyboard-dismissible; primary action right-most. |
| **ProgressOverlay** | For OCR/long ops: determinate where possible, cancelable (NFR-01). |
| **BudgetBullet / ProgressBar** | Actual vs budget with target marker and semantic over/under coloring. |

Every component ships with: tokens only (no hard-coded colors/sizes), full keyboard support, automation/screen-reader names, and light/dark variants.

## 5. Design tokens

Tokens are the contract between design and code; **no view hard-codes a raw color, size, or font**. Defined once (e.g. WinUI `ResourceDictionary` + theme dictionaries) and consumed by XAML and chart styling alike (so charts match the UI — P9).

```
Token groups
├─ color.neutral.{0..100}            surfaces, strokes, text
├─ color.accent.{default,hover,...}  brand/accent (follows OS accent)
├─ color.semantic.{income,expense,transfer,success,warning,danger,info}
├─ color.category.{1..12}            categorical, color-blind-aware
├─ space.{4,8,12,16,24,32,48,64}     8-pt grid
├─ radius.{sm,md,lg,pill}            corner radii
├─ elevation.{0,1,2,3}               shadows/strokes
├─ type.{caption,body,bodyStrong,subtitle,title,display}
├─ type.numeric                      tabular money style
├─ motion.duration.{fast,base,slow}  100/180/250ms
└─ motion.easing.{standard,emphasized}
```

Light and dark are two token sets behind the same names; high-contrast maps to system colors. Switching theme swaps the dictionary — no per-control logic.

## 6. Theming & personalization

- **Light / Dark / System** themes; follows Windows by default.
- **Accent**: follow Windows accent or pick an app accent.
- **High-contrast**: honor the OS high-contrast themes (P11).
- **Density**: comfortable / compact.
- **Color-blind-safe** category palette option (P4/P11).
- **Localization**: CS + EN strings; locale-aware number/date/currency formatting (NFR-08). Layouts tested for longer strings.

## 7. Patterns for the key finance flows

### 7.1 Fast capture (P6)
- `Add` opens a focused dialog with smart defaults (today, last account, base currency, merchant→category memory).
- Single-line "quick expense" by default; "Add items" reveals the split editor (P5).
- Keyboard flow: Tab through fields, Enter to save, `Ctrl+N` new, `Ctrl+Shift+N` save-and-new.

### 7.2 Scan review (trust + confidence)
- Side-by-side original + extracted form; **confidence-colored fields** (P2/P4); low-confidence highlighted and focused first.
- Reconciliation status (Σ lines vs total) always visible; nothing saves until confirmed (P7).

### 7.3 Reading the numbers (P3/P14)
- Money always via `MoneyText`; base vs original visually distinct; deltas show direction + magnitude + color.
- Charts: zero-baseline bars, honest scales, "show as table" alternative, drill-down to source transactions (P2).

### 7.4 Budgets & alerts (P10)
- Calm, dismissible "nearing/over budget" indicators; never modal nagging. Progress uses semantic colors + labels (not color alone).

## 8. Accessibility checklist (per screen — definition of done)

- [ ] Full keyboard reachability and visible focus order.
- [ ] Screen-reader names/roles on all interactive elements; charts have text summaries + data-table view.
- [ ] Contrast AA verified (light, dark, high-contrast).
- [ ] No information by color alone (icon/label/text accompanies).
- [ ] Respects OS text scaling and reduce-motion.
- [ ] Hit targets ≥ 32×32 px (≥ 40px for primary).
- [ ] Localized strings, no truncation of money/labels.

## 9. UX quality bar (definition of done — per screen)

- [ ] One clear primary action; ≤ 2 clicks to the screen's core task (NFR-06).
- [ ] Loading, empty, error, and success states all designed (not just the happy path).
- [ ] All destructive actions undoable; inline validation prevents bad input.
- [ ] Uses only tokens + library components (no bespoke one-off styling).
- [ ] Matches the relevant section of [06](06-ux-ui-spec.md) and these principles.
- [ ] Verified in light + dark, comfortable + compact, CS + EN, and at 150% text scale.

## 10. Reference inspiration (principles, not cloning)

Modern personal-finance UX done well — clean dashboards, strong category color systems, fast capture, honest charts: e.g. YNAB, Monarch, Copilot Money, Apple Wallet/Card summaries, Microsoft's own Fluent showcase apps. We borrow *principles* (clarity, calm, trust, speed), not layouts, and adapt to native Windows/Fluent conventions.

## 11. Handoff & implementation notes

- Maintain a **living "kitchen-sink" page** in the app (debug build) showing every component in every state across themes/densities — the visual regression surface.
- Consider authoring the token set + key screens in **Figma** mirrored to these tokens for design iteration before coding (optional; the Figma MCP tooling is available if desired).
- Charts are styled from the *same tokens* as the UI; never let a charting library impose its own default palette (P9).
