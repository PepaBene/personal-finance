# Analytics & Visualizations

**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform
**Charting:** **fl_chart** (primary, pure-Dart, all platforms) for native chart types; **syncfusion_flutter_charts** + **syncfusion_flutter_treemap** for advanced types (treemap, heat matrix); `graphic` noted as an alternative. Custom widgets / `CustomPainter` for chart types with no native equivalent (waterfall, calendar heatmap). All charts are styled from the **same Material 3 design tokens** as the rest of the UI ([12-design-system.md](12-design-system-and-ux.md)) — never a chart library's default palette. All views compute in **base currency**, honor the global filters, and run against the **local encrypted Drift/SQLite database** so analytics work fully offline.

---

## 1. Cross-cutting concepts

- **Offline-first compute**: every analytic is computed against the **local encrypted Drift/SQLite** database on the device. Because each device holds a full local copy ([04-data-model.md](04-data-model.md)), all dashboards, charts and reports work with **no network connection**. Cloud sync (PowerSync ↔ Supabase) only keeps the local data current across devices — it is never on the critical path for rendering analytics.
- **Global filter context**: date range, period grain, transaction type, category/subcategory, account, currency, merchant, tag, amount band, free-text. Every visualization subscribes to it (FR-ANL-05).
- **Base-currency aggregation**: all sums use `Transaction.baseAmount` / line base shares so multi-currency data is comparable (FR-CUR, FR-ANL-10).
- **Drill-down**: tapping/clicking any segment, bar or cell navigates to a filtered Transactions list (FR-ANL-10).
- **Period granularity**: day / week / month / quarter / year, chosen per chart.
- **Computed in the local DB**: aggregations use SQL `GROUP BY` / aggregate functions in Drift over indexed columns, so large datasets stay fast (NFR-01/02); results are cached per filter signature.

## 2. Metrics & KPIs

| Metric | Definition |
|--------|-----------|
| Total expense / income | Σ base amounts of Expense / Income in range. |
| Net cash flow | Income − Expense. |
| Account balance | Opening + signed transaction sums. |
| Spend by category | Σ line base-amounts grouped by category (splits respected). |
| Avg daily/monthly spend | Expense ÷ days/months in range. |
| MoM / YoY change | (current − prior) ÷ prior, per category & total. |
| Budget utilization | Actual ÷ budget per category (v0.3). |
| Top merchants | Σ spend grouped by merchant, ranked. |
| Recurring estimate | Detected periodic charges projected forward (v0.3). |

Because spending is tracked at **line-item** level, category analytics naturally handle multi-category bills — each line contributes to its own category.

## 3. Visualization catalog

| Chart | Purpose | Type | Rel |
|-------|---------|------|-----|
| Dashboard tiles | KPI summary + deltas | Stat cards / sparkline | MVP |
| **Spend by category** | Composition of spending | Donut / Pie (drill to sub) | MVP |
| **Spending over time** | Trend & seasonality | Line / **stacked area** by category | MVP |
| **Income vs expense** | Inflow/outflow balance | Grouped/stacked bar | MVP |
| **Category treemap** | Hierarchical share at a glance | Treemap | v0.3 |
| **Calendar heatmap** | Daily spend intensity | Heatmap grid | v0.3 |
| **Cash-flow waterfall** | How balance changed over a period | Waterfall | v0.3 |
| **MoM / YoY comparison** | Period-over-period | Clustered bars / small multiples | v0.3 |
| **Top merchants** | Where money goes by payee | Horizontal bar | v0.3 |
| **Budget vs actual** | Track against plan | Bullet / progress bars | v0.3 |
| **Recurring/subscriptions** | Fixed commitments | List + timeline | v0.3 |

**Library mapping:** native types (line, bar, pie/donut, stacked area, scatter, sparkline) come from **fl_chart**. Treemap and heat matrix use **syncfusion_flutter_treemap** / **syncfusion_flutter_charts**; waterfall and calendar heatmap are drawn with a custom widget / `CustomPainter`. `graphic` is kept as an alternative for grammar-of-graphics needs. All series are themed from the shared Material 3 tokens.

## 4. Reports & export

- **On-screen reports** for any period with the active filter.
- **CSV export** of underlying data (MVP, FR-DAT-04).
- **PDF report export** (v0.3, FR-DAT-06): a formatted summary — KPIs, category breakdown, trend chart, top transactions — for a chosen month/quarter/year, **generated locally on-device** via the `printing` / `pdf` packages (no server round-trip; works offline).

## 5. Recurring / subscription detection (v0.3)

Heuristic: group transactions by merchant + similar amount; detect regular intervals (≈ weekly/monthly/yearly) with low variance; flag as recurring and surface in a dedicated panel and on the dashboard. Runs over the local database. Lets the user spot subscriptions and forecast fixed costs.

## 6. Performance approach

- Pre-aggregate via SQL `GROUP BY` (period, category, merchant) in the local Drift/SQLite database rather than loading rows into memory.
- Maintain an optional **monthly rollup** cache as a **Drift table** for instant dashboards on very large datasets; invalidated on data change (including incoming sync).
- Charts receive already-binned series; UI virtualization for any backing lists.
- Recompute lazily on filter change with **debouncing**, and **cancel** superseded queries.

## 7. Interaction details

- Hover/long-press tooltips with exact base + original amounts and share %.
- Legend toggles series on/off (e.g. hide a category in stacked area).
- Synced filters: changing the date range updates every visible chart.
- Click/tap-through to transactions everywhere; breadcrumb back to the chart.
- Export current chart as PNG (rendered locally).

## 8. Future analytics (post-v1, ideas)

- Forecasting/projection of month-end spend from run-rate.
- Anomaly flags ("you spent 3× your usual on Dining this week").
- Savings-rate and net-worth-over-time (if accounts/assets are extended).

These are explicitly out of v1 scope (kept here so the data model leaves room for them).
