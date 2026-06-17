using Ledgerly.Domain.Common;

namespace Ledgerly.Application.Categorization;

/// <summary>Read model for an auto-categorization rule.</summary>
public sealed record RuleDto(Guid Id, RuleMatchType MatchType, string Pattern, Guid CategoryId, int Priority, bool IsEnabled);

/// <summary>Input for creating an auto-categorization rule (FR-CAT-05).</summary>
public sealed record CreateRuleRequest
{
    public required RuleMatchType MatchType { get; init; }

    public required string Pattern { get; init; }

    public required Guid CategoryId { get; init; }

    public int Priority { get; init; }

    public bool IsEnabled { get; init; } = true;
}
