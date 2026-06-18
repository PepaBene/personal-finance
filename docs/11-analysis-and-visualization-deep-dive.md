# Analysis & Visualization — Deep Dive

**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform
**Relationship to other docs:** This is the authoritative, detailed specification for the app's analytical surface. [07-analytics-visualizations.md](07-analytics-visualizations.md) is the higher-level summary; this document expands every view, metric formula, chart, and interaction. Data definitions reference [04-data-model.md](04-data-model.md); requirement IDs reference [02-functional-requirements.md](02-functional-requirements.md); charting and theming reference [03-architecture.md](03-architecture.md) and [12-design-system.md](12-design-system-and-ux.md).

---

## 1. Analytical foundations

### 1.1 The unit of analysis is the **line item**
All spending analysis aggregates `LineItem` rows, not transaction headers (ADR-006). This is what makes multi-category bills accurate: a single 842 CZK supermarket transaction contributes to Groceries, Household, **and** Alcohol simultaneously. Header-level metrics (cash flow, account balances, transaction counts) aggregate `Transaction` rows. Each metric below states which grain it uses.

### 1.2 Everything is in **base currency**
Every cross-record aggregate uses cached base-currency amounts so multi-currency data is comparable (FR-CUR, [04 §3](04-data-model.md)):
- Header metrics use `Transaction.baseAmount`.
- Line-level metrics use a **line base share** = `LineItem.lineAmount × Transaction.exchangeRate`, rounded with banker's rounding via the `Money` value object (stored as a decimal string; see [04 §3](04-data-model.md) and §9 performance).
Original-currency amounts are always available in tooltips and drill-downs, never lost.

### 1.3 Offline-first compute against the local database
Every metric and chart is computed against the **local encrypted Drift/SQLite** database on the device. Each device holds a full local copy of the user's data, so the entire analytical surface works **fully offline** — no request ever blocks on the network. The cloud (Supabase Postgres via PowerSync) exists only to keep that local data current across devices; sync deltas update the local tables, which in turn invalidate caches and re-stream results to the UI. There is no separate "server analytics" path.

### 1.4 The global filter context
A single shared filter object drives **every** view (FR-ANL-05). It is exposed as a Riverpod state object; changing it re-runs the affected local queries and re-renders all visible charts (debounced, cancelable):

| Filter | Values |
|--------|--------|
| Date range | presets (This month, Last month, This quarter, YTD, Last 12 months, Custom) + explicit from/to |
| Period grain | Day / Week / Month / Quarter / Year (auto-picked from range, overridable) |
| Transaction type | Expense / Income / Transfer / All |
| Category | one or many, optionally including subcategories |
| Account | one or many |
| Currency | original-currency filter (e.g. only EUR transactions) |
| Merchant | one or many |
| Tag | one or many |
| Text | free-text over description / note / merchant / OCR text |
| Amount band | min/max (base) |

Filter state is shareable across views, savable as **named views** (e.g. "Dining 2026"), and reflected in a breadcrumb so drill-downs are reversible.

### 1.5 Transfers & internal flows
Transfers (FR-ACC-03) are excluded from income/expense and category analytics by default (they move money, they don't spend it), but appear in account-balance and cash-flow-by-account views. A toggle can include them where relevant.

---

## 2. Metric catalog (exact definitions)

> `R` = active date range; amounts in base currency unless noted. "Expense lines" = `LineItem` whose `Transaction.type=Expense` and `Status=Active`, after filters.

| Metric | Grain | Formula / definition |
|--------|-------|----------------------|
| **Total expense** | line | Σ line base share over expense lines in R |
| **Total income** | header | Σ `baseAmount` over Income transactions in R |
| **Net cash flow** | header | Total income − Total expense |
| **Savings rate** | header | Net cash flow ÷ Total income (if income > 0) |
| **Account balance** | header | `openingBalance` + Σ signed transaction/transfer effects up to date |
| **Net worth (basic)** | header | Σ account balances in base currency at a point in time |
| **Spend by category** | line | Σ line base share grouped by `categoryId` (splits respected) |
| **Spend by parent category** | line | roll up subcategories to their root |
| **Avg daily spend** | line | Total expense ÷ number of days in R |
| **Avg monthly spend** | line | Total expense ÷ number of months in R |
| **Median transaction** | header | median of expense `baseAmount` (robust to outliers) |
| **Largest expense** | header | max expense `baseAmount` (+ link to it) |
| **Transaction count / frequency** | header | count of transactions; per period |
| **MoM change** | line/header | (current period − prior period) ÷ prior period |
| **YoY change** | line/header | (this period − same period last year) ÷ that value |
| **Run rate (month)** | line | Total expense so far this month ÷ days elapsed × days in month |
| **Budget utilization** | line | category actual ÷ category budget (v0.3) |
| **Budget remaining / pace** | line | budget − actual; and whether spend pace ≤ time-elapsed pace |
| **Top merchants** | header | Σ expense `baseAmount` grouped by `merchantId`, ranked |
| **Recurring monthly cost** | header | Σ of detected recurring charges normalized to monthly |
| **Effective FX exposure** | header | share of spend by original currency |
| **Category share %** | line | category spend ÷ total expense in R |

Each metric is implemented once in `AnalyticsService` (the Dart `application`-layer port, implemented in `data`) and reused by all views to guarantee numbers reconcile across screens.

---

## 3. Transaction views & exploration

Beyond the basic list in [06 §2.3](06-ux-ui-spec.md), the analysis surface offers:

### 3.1 Transaction explorer (the analytical grid)
- Virtualized list/grid: Date · Merchant · Category chips · Account · Amount (orig) · Amount (base) · Tags · Source/Attachment icons.
- **Group by** any dimension (category, merchant, account, month, tag) with subtotal rows and collapsible groups.
- **Inline split view**: expand a row to see its line items and per-line categories.
- **Aggregate footer**: count, sum (base), average, min/max for the current filtered set — updates live via a reactive Drift `Stream`.
- Sort by any column; multi-column sort.
- Saved filter presets surfaced as quick chips.
- **Bulk operations**: re-categorize, tag, delete, export selection (FR-CAT-07, FR-DAT-04).

### 3.2 Line-item explorer
A view at line granularity (one row per `LineItem`) for fine-grained category analysis — "show me every individual item categorized as Alcohol across all my receipts this year," with merchant and source transaction columns. This is impossible in header-only tools and is a differentiator enabled by the data model.

### 3.3 Search
Global text search spans description, note, merchant, tags, and **OCR text of attachments** (FR-SCAN-08), so the user can find "that pharmacy receipt with the prescription" by a word printed on it. Search runs against the local database and works offline.

---

## 4. Cash-flow analysis

Cash flow answers "what came in, what went out, and where did the balance go?" — at the header grain, transfers handled explicitly.

### 4.1 Income vs expense over time
- **Chart:** grouped or stacked bars per period (month default) via **fl_chart** `BarChart`; income above zero, expense below (diverging) or side-by-side.
- **Overlaid line:** net cash flow per period (fl_chart `LineChart` overlay).
- Drill: click a period → transactions for that period.

### 4.2 Cash-flow waterfall
- Shows how the balance moved across a period: starting balance → +income → −expense (optionally broken into top categories) → ending balance.
- No native waterfall type exists in fl_chart, so this is rendered with a **custom `CustomPainter`/widget** (or Syncfusion's waterfall series) over pre-computed cumulative deltas.
- Makes "why did my balance drop this much?" visually obvious.

### 4.3 Running balance / net-worth line
- **Chart:** fl_chart line/area of cumulative balance over time, per account or total (base currency).
- Optional projection of month-end balance from current run rate (dashed forward segment, v0.3).

### 4.4 Cash flow by account
- Stacked bars or small multiples showing inflow/outflow per account; transfers shown as internal movement (not net spend).

### 4.5 Recurring & fixed-cost view (v0.3)
- Detected recurring charges (heuristic in [07 §5](07-analytics-visualizations.md)) listed with cadence, amount, next expected date, and category.
- **Timeline strip** of upcoming fixed costs; a "committed monthly spend" KPI separating fixed from discretionary spending.

---

## 5. Category analysis

The richest area, all at line grain so splits are honored.

### 5.1 Category composition
- **Donut/Pie:** share of total expense by category for R via **fl_chart** `PieChart`; center shows total. Tap a slice → drill into subcategories, then transactions.
- **Treemap (v0.3):** hierarchical category → subcategory rectangles sized by spend via **syncfusion_flutter_treemap**; the fastest way to see "what dominates."
- **Horizontal ranked bars:** categories sorted by spend with share % labels (fl_chart) — better than pie when there are many categories.

### 5.2 Category trends
- **Stacked area:** spend per period stacked by category (fl_chart) — shows both total trend and shifting composition.
- **Small multiples / sparklines:** one mini-trend per category in a grid, for scanning which categories are rising/falling.
- **Legend toggles** to isolate or hide categories.

### 5.3 Category comparison
- **MoM / YoY per category:** clustered bars (this period vs prior) with % change badges; sortable by biggest mover.
- **Heat table:** categories (rows) × months (columns), cell shading by spend — seasonality at a glance; rendered via **syncfusion_flutter_charts** heat-map series or a custom grid widget.

### 5.4 Subcategory & tag breakdowns
- Drill from any category into its subcategories.
- **Tag analysis:** spend grouped by tag (cross-cutting labels independent of category) — e.g. a "vacation-2026" tag spanning Transport, Dining, Leisure.

### 5.5 Budget vs actual (v0.3)
- **Bullet charts / progress bars** per budgeted category: actual vs budget, with target marker and over/under coloring (custom widget over Material 3 tokens).
- Pace indicator: is spend tracking ahead of the month's elapsed fraction?
- Alerts surface on dashboard when nearing/over (FR-BUD-02).

---

## 6. Merchant & item analysis

- **Top merchants:** horizontal bar of spend by merchant (fl_chart); tap → that merchant's transactions and trend.
- **Merchant detail:** total spent, visit count, average ticket, first/last seen, category mix (mini donut), spend trend.
- **Item-level insights (line grain):** most frequent item descriptions, price trend of a recurring item over time (e.g. is your usual grocery basket getting more expensive) — enabled by line-item storage.

---

## 7. Time-pattern analysis

- **Calendar heatmap (v0.3):** a year grid, each day shaded by spend intensity — reveals heavy days, paydays, weekends. No native type exists, so this is a **custom `CustomPainter`/widget** over a daily-binned local query.
- **Day-of-week / time-of-month profiles:** bar charts (fl_chart) of average spend by weekday or by day-of-month, exposing habits.
- **Seasonality:** month-of-year averages across multiple years.

---

## 8. Visualization catalog (consolidated)

| Chart | Section | Grain | Library / type | Rel |
|-------|---------|-------|----------------|-----|
| KPI stat cards + delta | Dashboard | mixed | custom widgets | MVP |
| Sparklines | Dashboard / category grid | line | fl_chart line | MVP |
| Spend-by-category donut/pie | 5.1 | line | fl_chart pie/donut | MVP |
| Ranked category bars | 5.1 | line | fl_chart horizontal bar | MVP |
| Spending-over-time line | 4/5 | line | fl_chart line | MVP |
| Stacked area by category | 5.2 | line | fl_chart stacked area | MVP |
| Income vs expense bars | 4.1 | header | fl_chart grouped/stacked bar | MVP |
| Net cash-flow line overlay | 4.1 | header | fl_chart line | MVP |
| Running balance / net worth | 4.3 | header | fl_chart area/line | MVP→v0.3 |
| Cash-flow waterfall | 4.2 | header | custom CustomPainter (or Syncfusion) | v0.3 |
| Category treemap | 5.1 | line | syncfusion_flutter_treemap | v0.3 |
| Category heat table | 5.3 | line | syncfusion_flutter_charts heat-map (or custom grid) | v0.3 |
| MoM / YoY clustered bars | 5.3 | mixed | fl_chart grouped bar | v0.3 |
| Budget bullet/progress | 5.5 | line | custom widget | v0.3 |
| Top-merchants bar | 6 | header | fl_chart horizontal bar | v0.3 |
| Calendar heatmap | 7 | header/line | custom CustomPainter | v0.3 |
| Day-of-week / month profile | 7 | line | fl_chart bar | v0.3 |
| Recurring timeline | 4.5 | header | custom widget | v0.3 |

**Library mapping:** native types (line, bar, pie/donut, stacked area, scatter, sparkline) come from **fl_chart** (pure Dart, works on web, mobile, and desktop incl. Windows + macOS). Advanced types — **treemap** (`syncfusion_flutter_treemap`) and **heat matrix** (`syncfusion_flutter_charts`) — use Syncfusion. Chart types with no native equivalent — **waterfall** and **calendar heatmap** — are drawn with a custom `CustomPainter`/widget. `graphic` is retained as a grammar-of-graphics alternative. Every chart is themed from the **shared Material 3 design tokens** ([12-design-system.md](12-design-system-and-ux.md)), never a library's default palette. See [03 §2](03-architecture.md).

---

## 9. Common interactions (apply to all charts)

- **Drill-down everywhere:** tap any segment/bar/cell/slice → navigate to the filtered transaction (or line-item) list, with a breadcrumb back (FR-ANL-10).
- **Hover/long-press tooltip:** exact base amount, original amount(s), share %, period, count.
- **Legend toggle:** show/hide series (e.g. mute a category in stacked area).
- **Cross-filtering:** selecting a category in one chart can scope the others (optional "linked" mode).
- **Zoom/pan** on time-series; **period grain switch** in-chart.
- **Export:** any chart → PNG (rendered locally); underlying data → CSV; full view → PDF report (v0.3, FR-DAT-06, generated on-device via `printing`/`pdf`).
- **Empty/low-data states:** charts show a helpful placeholder rather than an empty axis.
- **Color = category color** from the `Category` entity, resolved through the Material 3 token palette and consistent across every chart, list chip, and picker (single source of truth, [12-design-system.md](12-design-system-and-ux.md)). Information is never conveyed by color alone (NFR-07): labels/icons accompany it.

---

## 10. Reports

- **Interactive on-screen report** for any period + filter set, combining KPIs, a category breakdown, a trend chart, top categories/merchants, and budget status.
- **Monthly/quarterly/annual summary** template.
- **PDF export** (v0.3, FR-DAT-06): formatted, paginated version of the on-screen report for archiving or sharing, **generated locally on-device** via the `printing` / `pdf` packages — works offline, no data leaves the device unless the user shares the file.
- **CSV export** (MVP, FR-DAT-04) of the exact rows behind any view for the user's own spreadsheet analysis.

---

## 11. Performance & correctness

- All aggregates are computed **in the local Drift/SQLite database** (SQL `GROUP BY`, sums, aggregate functions) over indexed columns ([04 §5](04-data-model.md)); rows are not loaded into memory to chart them (NFR-01/02). Because compute is local, performance is independent of network conditions.
- Charts receive pre-binned series; backing lists use UI virtualization.
- An optional **monthly rollup cache** — implemented as a **Drift table** (per category/merchant/account) — gives instant dashboards on 100k+ transactions; invalidated on any data change, including changes arriving via PowerSync sync.
- **Line base share** can be persisted (denormalized) or computed on the fly; if persisted, it's recomputed when base currency changes (background task, [04 §3.3](04-data-model.md)).
- All metrics flow through a single `AnalyticsService` so every screen's numbers reconcile (no two charts disagree on "total expense").
- Filter changes **debounce** (~150 ms) and **cancel** superseded queries; recompute is driven by reactive Drift streams so incoming sync updates refresh charts automatically.

---

## 12. Accessibility of data views (NFR-07)

- Every chart has a screen-reader summary exposed via Flutter **`Semantics`** widgets and an associated data table view ("show as table").
- Color-blind-safe category palette option (derived from the Material 3 tokens); patterns/labels supplement color.
- Full keyboard navigation of lists and chart drill-downs on desktop/web; focus-visible states. Touch targets and gestures on mobile.
- Respect system text scaling (`MediaQuery.textScaler`) and reduce-motion; charts re-layout rather than clip.

---

## 13. Out of scope for v1 (room left in the model)

Forecasting/projection beyond simple run-rate, anomaly detection ("3× your usual Dining"), goal tracking, and net-worth-with-assets are deliberately deferred ([07 §8](07-analytics-visualizations.md)). The line-item grain, historical FX, and rollup design leave room to add them without schema upheaval.
