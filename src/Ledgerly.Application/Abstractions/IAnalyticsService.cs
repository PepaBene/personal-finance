using Ledgerly.Application.Analytics;

namespace Ledgerly.Application.Abstractions;

/// <summary>
/// MVP analytics aggregates (FR-ANL-01..05, 10). All amounts are in the base currency;
/// transfers are excluded from income/expense and category analytics (docs/11 §1.4).
/// Spend-by-category aggregates at line-item grain so multi-category splits are honoured
/// (ADR-006); cash-flow totals aggregate at transaction-header grain.
/// </summary>
public interface IAnalyticsService
{
    Task<TotalsDto> GetTotalsAsync(AnalyticsFilter filter, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<CategorySpendDto>> GetSpendByCategoryAsync(AnalyticsFilter filter, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<PeriodTotalsDto>> GetOverTimeAsync(AnalyticsFilter filter, PeriodGrain grain, CancellationToken cancellationToken = default);
}
