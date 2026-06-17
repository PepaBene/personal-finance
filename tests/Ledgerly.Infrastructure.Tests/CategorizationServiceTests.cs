using FluentAssertions;
using Ledgerly.Application.Abstractions;
using Ledgerly.Application.Categorization;
using Ledgerly.Domain.Common;
using Ledgerly.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Ledgerly.Infrastructure.Tests;

public sealed class CategorizationServiceTests : IAsyncLifetime, IDisposable
{
    private const string Password = "categorization-tests-password";

    private readonly TempWorkspace _workspace = new();
    private ServiceProvider _provider = default!;
    private ICategorizationService _service = default!;

    public async Task InitializeAsync()
    {
        _provider = _workspace.BuildProvider();
        await _provider.GetRequiredService<IAppLock>().InitializeAsync(Password);
        _service = _provider.GetRequiredService<ICategorizationService>();
    }

    [Fact]
    public async Task DescriptionContainsRule_Wins()
    {
        var shopping = await GetCategoryIdAsync("Shopping");
        await _service.AddRuleAsync(new CreateRuleRequest
        {
            MatchType = RuleMatchType.DescriptionContains,
            Pattern = "gadget",
            CategoryId = shopping,
            Priority = 10,
        });

        (await _service.SuggestCategoryAsync("Cool Gadget X")).Should().Be(shopping);
    }

    [Fact]
    public async Task MerchantEqualsRule_MatchesOnMerchant()
    {
        var fuel = await GetCategoryIdAsync("Fuel");
        await _service.AddRuleAsync(new CreateRuleRequest
        {
            MatchType = RuleMatchType.MerchantEquals,
            Pattern = "Shell",
            CategoryId = fuel,
        });

        (await _service.SuggestCategoryAsync("pump 4", "shell")).Should().Be(fuel);
    }

    [Fact]
    public async Task MerchantMemory_SuggestsLearnedCategory()
    {
        var groceries = await GetCategoryIdAsync("Groceries");
        await _service.RememberMerchantCategoryAsync("Tesco", groceries);

        (await _service.SuggestCategoryAsync("weekly shop", "Tesco")).Should().Be(groceries);
    }

    [Fact]
    public async Task KeywordDictionary_SuggestsByKeyword()
    {
        var groceries = await GetCategoryIdAsync("Groceries");

        (await _service.SuggestCategoryAsync("Fresh milk 1L")).Should().Be(groceries);
    }

    [Fact]
    public async Task NoMatch_ReturnsNull()
    {
        (await _service.SuggestCategoryAsync("xyzzy unmatched")).Should().BeNull();
    }

    private async Task<Guid> GetCategoryIdAsync(string name)
    {
        var factory = _provider.GetRequiredService<IDbContextFactory<LedgerlyDbContext>>();
        await using var db = await factory.CreateDbContextAsync();
        return (await db.Categories.FirstAsync(c => c.Name == name)).Id;
    }

    public Task DisposeAsync()
    {
        _provider.Dispose();
        return Task.CompletedTask;
    }

    public void Dispose() => _workspace.Dispose();
}
