namespace Ledgerly.Application.Analytics;

/// <summary>The shared filter context every analytics view honours (FR-ANL-05).
/// A null/empty member means "no constraint on that dimension".</summary>
public sealed record AnalyticsFilter
{
    public DateOnly? From { get; init; }

    public DateOnly? To { get; init; }

    public IReadOnlyList<Guid>? CategoryIds { get; init; }

    public IReadOnlyList<Guid>? AccountIds { get; init; }
}
