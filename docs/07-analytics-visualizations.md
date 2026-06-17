# Analytics & Visualizations

**Version:** 0.1 · **Date:** 2026-06-09
**Charting:** LiveCharts2 (SkiaSharp) primary; ScottPlot alternative. All views compute in **base currency** and honor global filters.

---

## 1. Cross-cutting concepts

- **Global filter context**: date range, category/subcategory, account, currency, merchant, tag, free-text. Every visualization subscribes to it (FR-ANL-05).
- **Base-currency aggregation**: all sums use `Transaction.BaseAmount` / line shares so multi-currency data is comparable (FR-CUR, FR-ANL-10).
- **Drill-down**: clicking any segment/bar/cell navigates to a filtered Transactions list (FR-ANL-10).
- **Period granularity**: day / week / month / quarter / year, chosen per chart.
- **Computed in SQL**: aggregations use EF `GroupBy`/sums so large datasets stay fast (NFR-01/02); results cached per filter signature.

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

## 4. Reports & export

- **On-screen reports** for any period with the active filter.
- **CSV export** of underlying data (FR-DAT-04).
- **PDF report export** (v0.3, FR-DAT-06): a formatted summary — KPIs, category breakdown, trend chart, top transactions — for a chosen month/quarter/year.

## 5. Recurring / subscription detection (v0.3)

Heuristic: group transactions by merchant + similar amount; detect regular intervals (≈ weekly/monthly/yearly) with low variance; flag as recurring and surface in a dedicated panel and on the dashboard. Lets the user spot subscriptions and forecast fixed costs.

## 6. Performance approach

- Pre-aggregate via SQL `GROUP BY` (period, category, merchant) rather than loading rows into memory.
- Maintain optional **monthly rollup** cache table for instant dashboards on very large datasets.
- Charts receive already-binned series; UI virtualization for any backing lists.
- Recompute lazily on filter change with debouncing; cancel superseded queries.

## 7. Interaction details

- Hover tooltips with exact base + original amounts and share %.
- Legend toggles series on/off (e.g. hide a category in stacked area).
- Synced filters: changing the date range updates every visible chart.
- Click-through to transactions everywhere; breadcrumb back to the chart.
- Export current chart as PNG.

## 8. Future analytics (post-v1, ideas)

- Forecasting/projection of month-end spend from run-rate.
- Anomaly flags ("you spent 3× your usual on Dining this week").
- Savings-rate and net-worth-over-time (if accounts/assets are extended).
These are explicitly out of v1 scope (kept here so the data model leaves room for them).
