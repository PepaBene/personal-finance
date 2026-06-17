namespace Ledgerly.Application.Analytics;

/// <summary>Headline cash-flow totals in the base currency (FR-ANL-01). Transfers excluded.</summary>
public sealed record TotalsDto(decimal Income, decimal Expense, decimal Net, string BaseCurrency);

/// <summary>Spend for one category in the base currency, with its share of total expense (FR-ANL-02).</summary>
public sealed record CategorySpendDto(Guid CategoryId, string CategoryName, decimal Amount, decimal Share);

/// <summary>Income and expense for one period bucket, in the base currency (FR-ANL-03/04).</summary>
public sealed record PeriodTotalsDto(DateOnly PeriodStart, string Label, decimal Income, decimal Expense);
