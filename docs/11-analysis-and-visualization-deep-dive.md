# Analysis & Visualization — Deep Dive

**Version:** 0.1 · **Date:** 2026-06-09
**Relationship to other docs:** This is the authoritative, detailed specification for the app's analytical surface. [07-analytics-visualizations.md](07-analytics-visualizations.md) is the higher-level summary; this document expands every view, metric formula, chart, and interaction. Data definitions reference [04-data-model.md](04-data-model.md); requirement IDs reference [02-functional-requirements.md](02-functional-requirements.md).

---

## 1. Analytical foundations

### 1.1 The unit of analysis is the **line item**
All spending analysis aggregates `LineItem` rows, not transaction headers (ADR-006). This is what makes multi-category bills accurate: a single 842 CZK supermarket transaction contributes to Groceries, Household, **and** Alcohol simultaneously. Header-level metrics (cash flow, account balances, transaction counts) aggregate `Transaction` rows. Each metric below states which grain it uses.

### 1.2 Everything is in **base currency**
Every cross-record aggregate uses cached base-currency amounts so multi-currency data is comparable (FR-CUR, [04 §3](04-data-model.md)):
- Header metrics use `Transaction.BaseAmount`.
- Line-level metrics use a **line base share** = `LineItem.LineAmount × Transaction.ExchangeRate`, rounded with banker's rounding. (Stored or computed; see §9 performance.)
Original-currency amounts are always available in tooltips and drill-downs, never lost.

### 1.3 The global filter context
A single shared filter object drives **every** view (FR-ANL-05). Changing it re-renders all visible charts (debounced, cancelable):

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

### 1.4 Transfers & internal flows
Transfers (FR-ACC-03) are excluded from income/expense and category analytics by default (they move money, they don't spend it), but appear in account-balance and cash-flow-by-account views. A toggle can include them where relevant.

---

## 2. Metric catalog (exact definitions)

> `R` = active date range; amounts in base currency unless noted. "Expense lines" = `LineItem` whose `Transaction.Type=Expense` and `Status=Active`, after filters.

| Metric | Grain | Formula / definition |
|--------|-------|----------------------|
| **Total expense** | line | Σ line base share over expense lines in R |
| **Total income** | header | Σ `BaseAmount` over Income transactions in R |
| **Net cash flow** | header | Total income − Total expense |
| **Savings rate** | header | Net cash flow ÷ Total income (if income > 0) |
| **Account balance** | header | `OpeningBalance` + Σ signed transaction/transfer effects up to date |
| **Net worth (basic)** | header | Σ account balances in base currency at a point in time |
| **Spend by category** | line | Σ line base share grouped by `CategoryId` (splits respected) |
| **Spend by parent category** | line | roll up subcategories to their root |
| **Avg daily spend** | line | Total expense ÷ number of days in R |
| **Avg monthly spend** | line | Total expense ÷ number of months in R |
| **Median transaction** | header | median of expense `BaseAmount` (robust to outliers) |
| **Largest expense** | header | max expense `BaseAmount` (+ link to it) |
| **Transaction count / frequency** | header | count of transactions; per period |
| **MoM change** | line/header | (current period − prior period) ÷ prior period |
| **YoY change** | line/header | (this period − same period last year) ÷ that value |
| **Run rate (month)** | line | Total expense so far this month ÷ days elapsed × days in month |
| **Budget utilization** | line | category actual ÷ category budget (v0.3) |
| **Budget remaining / pace** | line | budget − actual; and whether spend pace ≤ time-elapsed pace |
| **Top merchants** | header | Σ expense `BaseAmount` grouped by `MerchantId`, ranked |
| **Recurring monthly cost** | header | Σ of detected recurring charges normalized to monthly |
| **Effective FX exposure** | header | share of spend by original currency |
| **Category share %** | line | category spend ÷ total expense in R |

Each metric is implemented once in `IAnalyticsService` and reused by all views to guarantee numbers reconcile across screens.

---

## 3. Transaction views & exploration

Beyond the basic grid in [06 §2.3](06-ux-ui-spec.md), the analysis surface offers:

### 3.1 Transaction explorer (the analytical grid)
- Virtualized grid: Date · Merchant · Category chips · Account · Amount (orig) · Amount (base) · Tags · Source/Attachment icons.
- **Group by** any dimension (category, merchant, account, month, tag) with subtotal rows and collapsible groups.
- **Inline split view**: expand a row to see its line items and per-line categories.
- **Aggregate footer**: count, sum (base), average, min/max for the current filtered set — updates live.
- Sort by any column; multi-column sort.
- Saved filter presets surfaced as quick chips.
- **Bulk operations**: re-categorize, tag, delete, export selection (FR-CAT-07, FR-DAT-04).

### 3.2 Line-item explorer
A grid at line granularity (one row per `LineItem`) for fine-grained category analysis — "show me every individual item categorized as Alcohol across all my receipts this year," with merchant and source transaction columns. This is impossible in header-only tools and is a differentiator enabled by the data model.

### 3.3 Search
Global text search spans description, note, merchant, tags, and **OCR text of attachments** (FR-SCAN-08), so the user can find "that pharmacy receipt with the prescription" by a word printed on it.

---

## 4. Cash-flow analysis

Cash flow answers "what came in, what went out, and where did the balance go?" — at the header grain, transfers handled explicitly.

### 4.1 Income vs expense over time
- **Chart:** grouped or stacked bars per period (month default); income above zero, expense below (diverging) or side-by-side.
- **Overlaid line:** net cash flow per period.
- Drill: click a period → transactions for that period.

### 4.2 Cash-flow waterfall
- Shows how the balance moved across a period: starting balance → +income → −expense (optionally broken into top categories) → ending balance.
- Makes "why did my balance drop this much?" visually obvious.

### 4.3 Running balance / net-worth line
- **Chart:** line/area of cumulative balance over time, per account or total (base currency).
- Optional projection of month-end balance from current run rate (dashed forward segment, v0.3).

### 4.4 Cash flow by account
- Stacked bars or small multiples showing inflow/outflow per account; transfers shown as internal movement (not net spend).

### 4.5 Recurring & fixed-cost view (v0.3)
- Detected recurring charges (§ heuristic in [07 §5](07-analytics-visualizations.md)) listed with cadence, amount, next expected date, and category.
- **Timeline strip** of upcoming fixed costs; a "committed monthly spend" KPI separating fixed from discretionary spending.

---

## 5. Category analysis

The richest area, all at line grain so splits are honored.

### 5.1 Category composition
- **Donut/Pie:** share of total expense by category for R; center shows total. Click a slice → drill into subcategories, then transactions.
- **Treemap (v0.3):** hierarchical category → subcategory rectangles sized by spend; the fastest way to see "what dominates."
- **Horizontal ranked bars:** categories sorted by spend with share % labels — better than pie when there are many categories.

### 5.2 Category trends
- **Stacked area:** spend per period stacked by category — shows both total trend and shifting composition.
- **Small multiples / sparklines:** one mini-trend per category in a grid, for scanning which categories are rising/falling.
- **Legend toggles** to isolate or hide categories.

### 5.3 Category comparison
- **MoM / YoY per category:** clustered bars (this period vs prior) with % change badges; sortable by biggest mover.
- **Heat table:** categories (rows) × months (columns), cell shading by spend — seasonality at a glance.

### 5.4 Subcategory & tag breakdowns
- Drill from any category into its subcategories.
- **Tag analysis:** spend grouped by tag (cross-cutting labels independent of category) — e.g. a "vacation-2026" tag spanning Transport, Dining, Leisure.

### 5.5 Budget vs actual (v0.3)
- **Bullet charts / progress bars** per budgeted category: actual vs budget, with target marker and over/under coloring.
- Pace indicator: is spend tracking ahead of the month's elapsed fraction?
- Alerts surface on dashboard when nearing/over (FR-BUD-02).

---

## 6. Merchant & item analysis

- **Top merchants:** horizontal bar of spend by merchant; click → that merchant's transactions and trend.
- **Merchant detail:** total spent, visit count, average ticket, first/last seen, category mix (mini donut), spend trend.
- **Item-level insights (line grain):** most frequent item descriptions, price trend of a recurring item over time (e.g. is your usual grocery basket getting more expensive) — enabled by line-item storage.

---

## 7. Time-pattern analysis

- **Calendar heatmap (v0.3):** a year grid, each day shaded by spend intensity — reveals heavy days, paydays, weekends.
- **Day-of-week / time-of-month profiles:** bar charts of average spend by weekday or by day-of-month, exposing habits.
- **Seasonality:** month-of-year averages across multiple years.

---

## 8. Visualization catalog (consolidated)

| Chart | Section | Grain | Library type | Rel |
|-------|---------|-------|--------------|-----|
| KPI stat cards + delta | Dashboard | mixed | custom tiles | MVP |
| Sparklines | Dashboard / category grid | line | line | MVP |
| Spend-by-category donut/pie | 5.1 | line | pie/doughnut | MVP |
| Ranked category bars | 5.1 | line | horizontal bar | MVP |
| Spending-over-time line | 4/5 | line | line | MVP |
| Stacked area by category | 5.2 | line | stacked area | MVP |
| Income vs expense bars | 4.1 | header | grouped/stacked bar | MVP |
| Net cash-flow line overlay | 4.1 | header | line | MVP |
| Running balance / net worth | 4.3 | header | area/line | MVP→v0.3 |
| Cash-flow waterfall | 4.2 | header | waterfall | v0.3 |
| Category treemap | 5.1 | line | treemap | v0.3 |
| Category heat table | 5.3 | line | matrix/heatmap | v0.3 |
| MoM / YoY clustered bars | 5.3 | mixed | grouped bar | v0.3 |
| Budget bullet/progress | 5.5 | line | bullet | v0.3 |
| Top-merchants bar | 6 | header | horizontal bar | v0.3 |
| Calendar heatmap | 7 | header/line | heatmap grid | v0.3 |
| Day-of-week / month profile | 7 | line | bar | v0.3 |
| Recurring timeline | 4.5 | header | timeline | v0.3 |

**Library mapping:** native types (line, bar, pie, area, scatter) come from **LiveCharts2**. Treemap, calendar heatmap, waterfall, and heat-matrix may need custom drawing (SkiaSharp via LiveCharts custom series) or **ScottPlot**; these are the v0.3 items, decided when built. See [03 §2](03-architecture.md).

---

## 9. Common interactions (apply to all charts)

- **Drill-down everywhere:** click any segment/bar/cell/slice → navigate to the filtered transaction (or line-item) list, with a breadcrumb back (FR-ANL-10).
- **Hover tooltip:** exact base amount, original amount(s), share %, period, count.
- **Legend toggle:** show/hide series (e.g. mute a category in stacked area).
- **Cross-filtering:** selecting a category in one chart can scope the others (optional "linked" mode).
- **Zoom/pan** on time-series; **period grain switch** in-chart.
- **Export:** any chart → PNG; underlying data → CSV; full view → PDF report (v0.3, FR-DAT-06).
- **Empty/low-data states:** charts show a helpful placeholder rather than an empty axis.
- **Color = category color** from the `Category` entity, consistent across every chart, grid chip, and picker (single source of truth, [06 §4](06-ux-ui-spec.md)). Information is never conveyed by color alone (NFR-07): labels/icons accompany it.

---

## 10. Reports

- **Interactive on-screen report** for any period + filter set, combining KPIs, a category breakdown, a trend chart, top categories/merchants, and budget status.
- **Monthly/quarterly/annual summary** template.
- **PDF export** (v0.3, FR-DAT-06): formatted, paginated version of the on-screen report for archiving or sharing, generated locally.
- **CSV export** (MVP, FR-DAT-04) of the exact rows behind any view for the user's own spreadsheet analysis.

---

## 11. Performance & correctness

- All aggregates computed **in SQL** (EF `GroupBy`, sums) over indexed columns ([04 §5](04-data-model.md)); rows are not loaded into memory to chart them (NFR-01/02).
- Charts receive pre-binned series; backing grids use UI virtualization.
- An optional **monthly rollup cache** (per category/merchant/account) gives instant dashboards on 100k+ transactions; invalidated on data change.
- **Line base share** can be persisted (denormalized) or computed on the fly; if persisted, it's recomputed when base currency changes (background job, [04 §3.3](04-data-model.md)).
- All metrics flow through a single `IAnalyticsService` so every screen's numbers reconcile (no two charts disagree on "total expense").
- Filter changes debounce (~150 ms) and cancel superseded queries.

---

## 12. Accessibility of data views (NFR-07)

- Every chart has a screen-reader summary and an associated data table view ("show as table").
- Color-blind-safe category palette option; patterns/labels supplement color.
- Full keyboard navigation of grids and chart drill-downs; focus-visible states.
- Respect system text scaling; charts re-layout rather than clip.

---

## 13. Out of scope for v1 (room left in the model)

Forecasting/projection beyond simple run-rate, anomaly detection ("3× your usual Dining"), goal tracking, and net-worth-with-assets are deliberately deferred ([07 §8](07-analytics-visualizations.md)). The line-item grain, historical FX, and rollup design leave room to add them without schema upheaval.
