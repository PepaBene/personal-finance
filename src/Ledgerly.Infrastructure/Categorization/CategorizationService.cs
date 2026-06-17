using System.Text.RegularExpressions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Categorization;
using Ledgerly.Domain.Common;
using Ledgerly.Domain.Entities;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Ledgerly.Infrastructure.Categorization;

/// <inheritdoc />
public sealed class CategorizationService : ICategorizationService
{
    private static readonly TimeSpan RegexTimeout = TimeSpan.FromMilliseconds(100);

    // Keyword -> seeded category name (docs/05 §6 step 3). Lower-case keys.
    private static readonly (string Keyword, string CategoryName)[] KeywordMap =
    [
        ("milk", "Groceries"), ("mléko", "Groceries"), ("bread", "Groceries"), ("chléb", "Groceries"),
        ("restaurant", "Dining"), ("cafe", "Dining"), ("coffee", "Dining"), ("pizza", "Dining"),
        ("fuel", "Fuel"), ("benzin", "Fuel"), ("diesel", "Fuel"),
        ("pharmacy", "Health"), ("lékárna", "Health"),
    ];

    private readonly IDbContextFactory<LedgerlyDbContext> _contextFactory;

    public CategorizationService(IDbContextFactory<LedgerlyDbContext> contextFactory)
    {
        _contextFactory = contextFactory;
    }

    public async Task<Guid?> SuggestCategoryAsync(
        string description,
        string? merchantName = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(description);

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);

        // 1) Rules, in priority order (first match wins).
        var rules = await db.CategorizationRules.AsNoTracking()
            .Where(r => r.IsEnabled)
            .OrderBy(r => r.Priority)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);
        foreach (var rule in rules)
        {
            if (Matches(rule, description, merchantName))
            {
                return rule.CategoryId;
            }
        }

        // 2) Merchant's learned default category.
        if (!string.IsNullOrWhiteSpace(merchantName))
        {
            var name = merchantName.Trim();
            var merchant = await db.Merchants.AsNoTracking()
                .FirstOrDefaultAsync(m => m.Name == name && m.DefaultCategoryId != null, cancellationToken)
                .ConfigureAwait(false);
            if (merchant?.DefaultCategoryId is { } categoryId)
            {
                return categoryId;
            }
        }

        // 3) Keyword dictionary.
        foreach (var (keyword, categoryName) in KeywordMap)
        {
            if (description.Contains(keyword, StringComparison.OrdinalIgnoreCase))
            {
                var category = await db.Categories.AsNoTracking()
                    .FirstOrDefaultAsync(c => c.Name == categoryName, cancellationToken)
                    .ConfigureAwait(false);
                if (category is not null)
                {
                    return category.Id;
                }
            }
        }

        // 4) Uncategorized.
        return null;
    }

    public async Task RememberMerchantCategoryAsync(
        string merchantName,
        Guid categoryId,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(merchantName))
        {
            return;
        }

        var name = merchantName.Trim();
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var merchant = await db.Merchants.FirstOrDefaultAsync(m => m.Name == name, cancellationToken).ConfigureAwait(false);
        if (merchant is null)
        {
            db.Merchants.Add(new Merchant { Name = name, DefaultCategoryId = categoryId });
        }
        else
        {
            merchant.DefaultCategoryId = categoryId;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task<RuleDto> AddRuleAsync(CreateRuleRequest request, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (string.IsNullOrWhiteSpace(request.Pattern))
        {
            throw new ArgumentException("A rule pattern is required.", nameof(request));
        }

        var rule = new CategorizationRule
        {
            MatchType = request.MatchType,
            Pattern = request.Pattern.Trim(),
            CategoryId = request.CategoryId,
            Priority = request.Priority,
            IsEnabled = request.IsEnabled,
        };

        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        db.CategorizationRules.Add(rule);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        return Map(rule);
    }

    public async Task<IReadOnlyList<RuleDto>> GetRulesAsync(CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var rules = await db.CategorizationRules.AsNoTracking()
            .OrderBy(r => r.Priority)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);
        return rules.Select(Map).ToList();
    }

    public async Task DeleteRuleAsync(Guid id, CancellationToken cancellationToken = default)
    {
        await using var db = await _contextFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var rule = await db.CategorizationRules.FirstOrDefaultAsync(r => r.Id == id, cancellationToken).ConfigureAwait(false);
        if (rule is null)
        {
            return;
        }

        db.CategorizationRules.Remove(rule);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    private static bool Matches(CategorizationRule rule, string description, string? merchantName) => rule.MatchType switch
    {
        RuleMatchType.MerchantEquals => !string.IsNullOrWhiteSpace(merchantName)
            && string.Equals(merchantName.Trim(), rule.Pattern.Trim(), StringComparison.OrdinalIgnoreCase),
        RuleMatchType.DescriptionContains => description.Contains(rule.Pattern, StringComparison.OrdinalIgnoreCase),
        RuleMatchType.Regex => TryRegexMatch(rule.Pattern, description),
        _ => false,
    };

    private static bool TryRegexMatch(string pattern, string input)
    {
        try
        {
            return Regex.IsMatch(input, pattern, RegexOptions.IgnoreCase, RegexTimeout);
        }
        catch (ArgumentException)
        {
            return false; // invalid pattern never matches
        }
        catch (RegexMatchTimeoutException)
        {
            return false;
        }
    }

    private static RuleDto Map(CategorizationRule r) =>
        new(r.Id, r.MatchType, r.Pattern, r.CategoryId, r.Priority, r.IsEnabled);
}
