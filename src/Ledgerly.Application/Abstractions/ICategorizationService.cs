using Ledgerly.Application.Categorization;

namespace Ledgerly.Application.Abstractions;

/// <summary>
/// Auto-categorization (FR-CAT-05/06, docs/05 §6): suggests a category for a line via,
/// in order, matching rules → merchant default → keyword dictionary → none; and learns
/// a merchant's category for next time.
/// </summary>
public interface ICategorizationService
{
    Task<Guid?> SuggestCategoryAsync(string description, string? merchantName = null, CancellationToken cancellationToken = default);

    /// <summary>Remembers a merchant's category so it is suggested next time (FR-CAT-06).</summary>
    Task RememberMerchantCategoryAsync(string merchantName, Guid categoryId, CancellationToken cancellationToken = default);

    Task<RuleDto> AddRuleAsync(CreateRuleRequest request, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RuleDto>> GetRulesAsync(CancellationToken cancellationToken = default);

    Task DeleteRuleAsync(Guid id, CancellationToken cancellationToken = default);
}
