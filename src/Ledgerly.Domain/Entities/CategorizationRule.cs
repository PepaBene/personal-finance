using Ledgerly.Domain.Common;

namespace Ledgerly.Domain.Entities;

/// <summary>
/// An auto-categorization rule applied in priority order during parsing and as a
/// "re-apply rules" action (docs/04 §4.1, FR-CAT-05). First match wins.
/// </summary>
public class CategorizationRule
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public RuleMatchType MatchType { get; set; }

    public string Pattern { get; set; } = default!;

    public Guid CategoryId { get; set; }

    public int Priority { get; set; }

    public bool IsEnabled { get; set; } = true;
}
